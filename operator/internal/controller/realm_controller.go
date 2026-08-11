package controller

import (
	"context"
	"fmt"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	mmov1alpha1 "github.com/rejdeboer/mmo-deployment/api/v1alpha1"
)

const (
	zoneNameLabel   = "mmo.rejdeboer.com/zone-name"
	realmOwnerLabel = "mmo.rejdeboer.com/realm"
	layerLabel      = "mmo.rejdeboer.com/layer"
)

// RealmReconciler reconciles a Realm object
type RealmReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=mmo.rejdeboer.com,resources=realms,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=mmo.rejdeboer.com,resources=realms/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=mmo.rejdeboer.com,resources=realms/finalizers,verbs=update
//+kubebuilder:rbac:groups=mmo.rejdeboer.com,resources=zonesets,verbs=get;list;watch
//+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete

func (r *RealmReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := logf.FromContext(ctx)

	var realm mmov1alpha1.Realm
	if err := r.Get(ctx, req.NamespacedName, &realm); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	var zoneSet mmov1alpha1.ZoneSet
	if err := r.Get(ctx, types.NamespacedName{
		Name:      realm.Spec.ZoneSetRef,
		Namespace: realm.Namespace,
	}, &zoneSet); err != nil {
		log.Error(err, "unable to fetch ZoneSet", "zoneSet", realm.Spec.ZoneSetRef)
		r.setCondition(&realm, "Ready", metav1.ConditionFalse, "ZoneSetNotFound",
			fmt.Sprintf("ZoneSet %q not found", realm.Spec.ZoneSetRef))
		_ = r.Status().Update(ctx, &realm)
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Build set of desired zone names for orphan cleanup
	desiredZones := make(map[string]mmov1alpha1.ZoneSpec, len(zoneSet.Spec.Zones))
	for _, zone := range zoneSet.Spec.Zones {
		desiredZones[zone.Name] = zone
	}

	// Reconcile deployments for each zone (layer 1 only for now)
	zoneStatuses := make([]mmov1alpha1.ZoneStatus, 0, len(zoneSet.Spec.Zones))
	allReady := true

	for _, zone := range zoneSet.Spec.Zones {
		if err := r.reconcileZoneDeployment(ctx, &realm, zone); err != nil {
			log.Error(err, "failed to reconcile zone deployment", "zone", zone.Name)
			return ctrl.Result{}, err
		}

		status := r.getZoneStatus(ctx, &realm, zone)
		zoneStatuses = append(zoneStatuses, status)

		ready := false
		for _, layer := range status.Layers {
			if layer.Phase == corev1.PodRunning {
				ready = true
				break
			}
		}
		if !ready {
			allReady = false
		}
	}

	// Clean up deployments for zones that no longer exist
	if err := r.cleanupOrphanedResources(ctx, &realm, desiredZones); err != nil {
		log.Error(err, "failed to clean up orphaned resources")
		return ctrl.Result{}, err
	}

	// Update status
	realm.Status.Zones = zoneStatuses
	if allReady {
		r.setCondition(&realm, "Ready", metav1.ConditionTrue, "AllZonesRunning", "All zones are running")
	} else {
		r.setCondition(&realm, "Ready", metav1.ConditionFalse, "ZonesNotReady", "Not all zones are running")
	}

	if err := r.Status().Update(ctx, &realm); err != nil {
		log.Error(err, "failed to update realm status")
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *RealmReconciler) reconcileZoneDeployment(ctx context.Context, realm *mmov1alpha1.Realm, zone mmov1alpha1.ZoneSpec) error {
	// For now, only create layer 1. Future: scale up layers based on player count.
	layerNum := int32(1)
	deployName := zoneDeploymentName(realm.Name, zone.Name, layerNum)
	layerPort := layerHostPort(zone.Port, layerNum)

	deploy := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      deployName,
			Namespace: realm.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, deploy, func() error {
		replicas := int32(1)
		deploy.Spec.Replicas = &replicas

		labels := map[string]string{
			realmOwnerLabel: realm.Name,
			zoneNameLabel:   zone.Name,
			layerLabel:      fmt.Sprintf("%d", layerNum),
		}

		deploy.Labels = labels
		deploy.Spec.Selector = &metav1.LabelSelector{
			MatchLabels: labels,
		}

		// Build pod template from realm template
		template := realm.Spec.Template.DeepCopy()

		// Merge labels
		if template.Labels == nil {
			template.Labels = make(map[string]string)
		}
		for k, v := range labels {
			template.Labels[k] = v
		}

		// Apply per-zone resource overrides and env vars to first container
		if len(template.Spec.Containers) > 0 {
			c := &template.Spec.Containers[0]

			if zone.Resources.Limits != nil || zone.Resources.Requests != nil {
				c.Resources = zone.Resources
			}

			c.Env = append(c.Env,
				corev1.EnvVar{Name: "ZONE_NAME", Value: zone.Name},
				corev1.EnvVar{Name: "REALM_NAME", Value: realm.Name},
				corev1.EnvVar{Name: "ZONE_PORT", Value: fmt.Sprintf("%d", layerPort)},
				corev1.EnvVar{Name: "LAYER", Value: fmt.Sprintf("%d", layerNum)},
			)
			if zone.PlayerCap != nil {
				c.Env = append(c.Env,
					corev1.EnvVar{Name: "PLAYER_CAP", Value: fmt.Sprintf("%d", *zone.PlayerCap)},
				)
			}

			// Set hostPort on the game port — direct network path, no kube-proxy overhead
			c.Ports = []corev1.ContainerPort{
				{
					Name:          "game",
					ContainerPort: layerPort,
					HostPort:      layerPort,
					Protocol:      corev1.ProtocolUDP,
				},
			}
		}

		// Readiness probe — zone server must expose a /readyz endpoint to signal
		// it has loaded world data and is ready to accept players.
		if len(template.Spec.Containers) > 0 {
			c := &template.Spec.Containers[0]
			if c.ReadinessProbe == nil {
				c.ReadinessProbe = &corev1.Probe{
					ProbeHandler: corev1.ProbeHandler{
						HTTPGet: &corev1.HTTPGetAction{
							Path: "/readyz",
							Port: intstr.FromInt32(8080),
						},
					},
					InitialDelaySeconds: 5,
					PeriodSeconds:       10,
				}
			}
		}

		// Graceful shutdown: give zone servers enough time to flush player state
		// to the database before the pod is killed.
		gracePeriod := int64(120)
		template.Spec.TerminationGracePeriodSeconds = &gracePeriod

		// Anti-affinity: prevent two zone pods from the same realm landing on the
		// same node, which would cause hostPort conflicts.
		template.Spec.Affinity = &corev1.Affinity{
			PodAntiAffinity: &corev1.PodAntiAffinity{
				PreferredDuringSchedulingIgnoredDuringExecution: []corev1.WeightedPodAffinityTerm{
					{
						Weight: 100,
						PodAffinityTerm: corev1.PodAffinityTerm{
							LabelSelector: &metav1.LabelSelector{
								MatchLabels: map[string]string{
									realmOwnerLabel: realm.Name,
								},
							},
							TopologyKey: "kubernetes.io/hostname",
						},
					},
				},
			},
		}

		deploy.Spec.Template = *template

		return controllerutil.SetControllerReference(realm, deploy, r.Scheme)
	})

	return err
}

func (r *RealmReconciler) getZoneStatus(ctx context.Context, realm *mmov1alpha1.Realm, zone mmov1alpha1.ZoneSpec) mmov1alpha1.ZoneStatus {
	status := mmov1alpha1.ZoneStatus{
		Name: zone.Name,
	}

	// For now, only layer 1 exists
	layerNum := int32(1)
	deployName := zoneDeploymentName(realm.Name, zone.Name, layerNum)
	layerPort := layerHostPort(zone.Port, layerNum)

	layerStatus := mmov1alpha1.LayerStatus{
		Layer: layerNum,
		Port:  layerPort,
	}

	// Get the pod for this deployment to find node address
	var pods corev1.PodList
	if err := r.List(ctx, &pods, client.InNamespace(realm.Namespace), client.MatchingLabels{
		realmOwnerLabel: realm.Name,
		zoneNameLabel:   zone.Name,
		layerLabel:      fmt.Sprintf("%d", layerNum),
	}); err == nil && len(pods.Items) > 0 {
		pod := &pods.Items[0]
		layerStatus.Phase = pod.Status.Phase
		if pod.Status.HostIP != "" {
			layerStatus.Address = pod.Status.HostIP
		}
	} else {
		// Fall back to deployment status for phase
		var deploy appsv1.Deployment
		if err := r.Get(ctx, types.NamespacedName{Name: deployName, Namespace: realm.Namespace}, &deploy); err == nil {
			if deploy.Status.ReadyReplicas > 0 {
				layerStatus.Phase = corev1.PodRunning
			} else {
				layerStatus.Phase = corev1.PodPending
			}
		}
	}

	status.Layers = []mmov1alpha1.LayerStatus{layerStatus}
	return status
}

func (r *RealmReconciler) cleanupOrphanedResources(ctx context.Context, realm *mmov1alpha1.Realm, desiredZones map[string]mmov1alpha1.ZoneSpec) error {
	var deployments appsv1.DeploymentList
	if err := r.List(ctx, &deployments, client.InNamespace(realm.Namespace), client.MatchingLabels{
		realmOwnerLabel: realm.Name,
	}); err != nil {
		return err
	}

	for i := range deployments.Items {
		deploy := &deployments.Items[i]
		zoneName := deploy.Labels[zoneNameLabel]
		if _, exists := desiredZones[zoneName]; !exists {
			if err := r.Delete(ctx, deploy); err != nil && !apierrors.IsNotFound(err) {
				return err
			}
		}
	}

	return nil
}

func (r *RealmReconciler) setCondition(realm *mmov1alpha1.Realm, condType string, status metav1.ConditionStatus, reason, message string) {
	condition := metav1.Condition{
		Type:               condType,
		Status:             status,
		ObservedGeneration: realm.Generation,
		LastTransitionTime: metav1.Now(),
		Reason:             reason,
		Message:            message,
	}

	for i, c := range realm.Status.Conditions {
		if c.Type == condType {
			if c.Status == status {
				condition.LastTransitionTime = c.LastTransitionTime
			}
			realm.Status.Conditions[i] = condition
			return
		}
	}
	realm.Status.Conditions = append(realm.Status.Conditions, condition)
}

// SetupWithManager sets up the controller with the Manager.
func (r *RealmReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&mmov1alpha1.Realm{}).
		Owns(&appsv1.Deployment{}).
		Watches(&mmov1alpha1.ZoneSet{}, handler.EnqueueRequestsFromMapFunc(r.findRealmsForZoneSet)).
		Named("realm").
		Complete(r)
}

// findRealmsForZoneSet maps a ZoneSet change to all Realms that reference it
func (r *RealmReconciler) findRealmsForZoneSet(ctx context.Context, obj client.Object) []reconcile.Request {
	zoneSet := obj.(*mmov1alpha1.ZoneSet)

	var realmList mmov1alpha1.RealmList
	if err := r.List(ctx, &realmList, client.InNamespace(zoneSet.Namespace)); err != nil {
		return nil
	}

	var requests []reconcile.Request
	for _, realm := range realmList.Items {
		if realm.Spec.ZoneSetRef == zoneSet.Name {
			requests = append(requests, reconcile.Request{
				NamespacedName: types.NamespacedName{
					Name:      realm.Name,
					Namespace: realm.Namespace,
				},
			})
		}
	}
	return requests
}

func zoneDeploymentName(realmName, zoneName string, layer int32) string {
	if layer == 1 {
		return fmt.Sprintf("%s-%s", realmName, zoneName)
	}
	return fmt.Sprintf("%s-%s-layer%d", realmName, zoneName, layer)
}

// layerHostPort computes the host port for a given layer.
// Layer 1 uses the zone's base port. Additional layers use base + (layer-1) * portStride.
// This reserves space between zone ports for future layers.
func layerHostPort(basePort int32, layer int32) int32 {
	const portStride = 100
	if layer == 1 {
		return basePort
	}
	return basePort + (layer-1)*portStride
}

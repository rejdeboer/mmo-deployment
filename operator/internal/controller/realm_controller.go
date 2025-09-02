package controller

import (
	"context"
	"maps"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	mmov1alpha1 "github.com/rejdeboer/mmo-deployment/api/v1alpha1"
)

const (
	zoneNameLabel   = "mmo.rejdeboer.com/zone-name"
	realmOwnerLabel = "mmo.rejdeboer.com/realm"
)

// RealmReconciler reconciles a Realm object
type RealmReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=mmo.yourcompany.com,resources=realms,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=mmo.yourcompany.com,resources=realms/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=mmo.yourcompany.com,resources=realms/finalizers,verbs=update
//+kubebuilder:rbac:groups=mmo.yourcompany.com,resources=zonesets,verbs=get;list;watch
//+kubebuilder:rbac:groups=apps,resources=statefulsets,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups="",resources=pods,verbs=get;list;watch;update;patch

// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.21.0/pkg/reconcile
func (r *RealmReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := logf.FromContext(ctx)

	var realm mmov1alpha1.Realm
	if err := r.Get(ctx, req.NamespacedName, &realm); err != nil {
		log.Error(err, "unable to fetch Realm")
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	var zoneSet mmov1alpha1.ZoneSet
	if err := r.Get(ctx, types.NamespacedName{Name: *realm.Spec.ZoneSetRef}, &zoneSet); err != nil {
		log.Error(err, "unable to fetch ZoneSet")
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	return ctrl.Result{}, nil
}

func (r *RealmReconciler) reconcileStatefulSet(ctx context.Context, realm *mmov1alpha1.Realm, zoneSet *mmov1alpha1.ZoneSet) error {
	sts := &appsv1.StatefulSet{
		ObjectMeta: metav1.ObjectMeta{
			Name:      realm.Name,
			Namespace: realm.Namespace,
		},
	}

	replicas := int32(len(zoneSet.Spec.Zones))
	realmLabels := map[string]string{realmOwnerLabel: realm.Name}
	template := realm.Spec.Template
	maps.Copy(template.ObjectMeta.Labels, realmLabels)

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, sts, func() error {
		sts.Spec = appsv1.StatefulSetSpec{
			Replicas:    &replicas,
			ServiceName: realm.Name,
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{realmOwnerLabel: realm.Name},
			},
			Template: template,
		}
		return controllerutil.SetControllerReference(realm, sts, r.Scheme)
	})

	return err
}

// SetupWithManager sets up the controller with the Manager.
func (r *RealmReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&mmov1alpha1.Realm{}).
		Named("realm").
		Complete(r)
}

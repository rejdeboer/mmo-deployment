package controller

import (
	"context"

	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	mmov1alpha1 "github.com/rejdeboer/mmo-deployment/api/v1alpha1"
)

// RealmReconciler reconciles a Realm object
type RealmReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=mmo.rejdeboer.com,resources=realms,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=mmo.rejdeboer.com,resources=realms/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=mmo.rejdeboer.com,resources=realms/finalizers,verbs=update

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

// SetupWithManager sets up the controller with the Manager.
func (r *RealmReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&mmov1alpha1.Realm{}).
		Named("realm").
		Complete(r)
}

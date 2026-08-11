/*
Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	mmov1alpha1 "github.com/rejdeboer/mmo-deployment/api/v1alpha1"
)

var _ = Describe("Realm Controller", func() {
	Context("When reconciling a resource", func() {
		const (
			realmName   = "test-realm"
			zoneSetName = "test-zoneset"
			namespace   = "default"
		)

		ctx := context.Background()

		BeforeEach(func() {
			// Create ZoneSet first
			zoneSet := &mmov1alpha1.ZoneSet{
				ObjectMeta: metav1.ObjectMeta{
					Name:      zoneSetName,
					Namespace: namespace,
				},
				Spec: mmov1alpha1.ZoneSetSpec{
					Zones: []mmov1alpha1.ZoneSpec{
						{Name: "elwynn-forest", Port: 7001},
						{Name: "stormwind", Port: 7002},
					},
				},
			}
			err := k8sClient.Get(ctx, types.NamespacedName{Name: zoneSetName, Namespace: namespace}, zoneSet)
			if err != nil && errors.IsNotFound(err) {
				Expect(k8sClient.Create(ctx, zoneSet)).To(Succeed())
			}

			// Create Realm
			realm := &mmov1alpha1.Realm{}
			err = k8sClient.Get(ctx, types.NamespacedName{Name: realmName, Namespace: namespace}, realm)
			if err != nil && errors.IsNotFound(err) {
				realm = &mmov1alpha1.Realm{
					ObjectMeta: metav1.ObjectMeta{
						Name:      realmName,
						Namespace: namespace,
					},
					Spec: mmov1alpha1.RealmSpec{
						ZoneSetRef: zoneSetName,
						Template: corev1.PodTemplateSpec{
							ObjectMeta: metav1.ObjectMeta{
								Labels: map[string]string{"app": "zone-server"},
							},
							Spec: corev1.PodSpec{
								Containers: []corev1.Container{
									{
										Name:  "zone-server",
										Image: "zone-server:test",
									},
								},
							},
						},
					},
				}
				Expect(k8sClient.Create(ctx, realm)).To(Succeed())
			}
		})

		AfterEach(func() {
			// Clean up realm
			realm := &mmov1alpha1.Realm{}
			if err := k8sClient.Get(ctx, types.NamespacedName{Name: realmName, Namespace: namespace}, realm); err == nil {
				Expect(k8sClient.Delete(ctx, realm)).To(Succeed())
			}
			// Clean up zoneset
			zoneSet := &mmov1alpha1.ZoneSet{}
			if err := k8sClient.Get(ctx, types.NamespacedName{Name: zoneSetName, Namespace: namespace}, zoneSet); err == nil {
				Expect(k8sClient.Delete(ctx, zoneSet)).To(Succeed())
			}
		})

		It("should create a deployment per zone with hostPort", func() {
			controllerReconciler := &RealmReconciler{
				Client: k8sClient,
				Scheme: k8sClient.Scheme(),
			}

			_, err := controllerReconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: types.NamespacedName{Name: realmName, Namespace: namespace},
			})
			Expect(err).NotTo(HaveOccurred())

			// Verify deployments were created for each zone
			zones := map[string]int32{
				"elwynn-forest": 7001,
				"stormwind":     7002,
			}
			for zoneName, expectedPort := range zones {
				deployName := zoneDeploymentName(realmName, zoneName, 1)

				var deploy appsv1.Deployment
				err := k8sClient.Get(ctx, types.NamespacedName{Name: deployName, Namespace: namespace}, &deploy)
				Expect(err).NotTo(HaveOccurred())
				Expect(deploy.Labels[zoneNameLabel]).To(Equal(zoneName))
				Expect(deploy.Labels[realmOwnerLabel]).To(Equal(realmName))
				Expect(*deploy.Spec.Replicas).To(Equal(int32(1)))

				// Verify hostPort is set
				containers := deploy.Spec.Template.Spec.Containers
				Expect(containers).NotTo(BeEmpty())
				Expect(containers[0].Ports).NotTo(BeEmpty())
				Expect(containers[0].Ports[0].HostPort).To(Equal(expectedPort))
				Expect(containers[0].Ports[0].Protocol).To(Equal(corev1.ProtocolUDP))
			}
		})

		It("should set pod anti-affinity to spread zones across nodes", func() {
			controllerReconciler := &RealmReconciler{
				Client: k8sClient,
				Scheme: k8sClient.Scheme(),
			}

			_, err := controllerReconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: types.NamespacedName{Name: realmName, Namespace: namespace},
			})
			Expect(err).NotTo(HaveOccurred())

			var deploy appsv1.Deployment
			err = k8sClient.Get(ctx, types.NamespacedName{
				Name:      zoneDeploymentName(realmName, "elwynn-forest", 1),
				Namespace: namespace,
			}, &deploy)
			Expect(err).NotTo(HaveOccurred())

			affinity := deploy.Spec.Template.Spec.Affinity
			Expect(affinity).NotTo(BeNil())
			Expect(affinity.PodAntiAffinity).NotTo(BeNil())
			preferred := affinity.PodAntiAffinity.PreferredDuringSchedulingIgnoredDuringExecution
			Expect(preferred).To(HaveLen(1))
			Expect(preferred[0].Weight).To(Equal(int32(100)))
			Expect(preferred[0].PodAffinityTerm.TopologyKey).To(Equal("kubernetes.io/hostname"))
			Expect(preferred[0].PodAffinityTerm.LabelSelector.MatchLabels[realmOwnerLabel]).To(Equal(realmName))
		})

		It("should set terminationGracePeriodSeconds to 120", func() {
			controllerReconciler := &RealmReconciler{
				Client: k8sClient,
				Scheme: k8sClient.Scheme(),
			}

			_, err := controllerReconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: types.NamespacedName{Name: realmName, Namespace: namespace},
			})
			Expect(err).NotTo(HaveOccurred())

			var deploy appsv1.Deployment
			err = k8sClient.Get(ctx, types.NamespacedName{
				Name:      zoneDeploymentName(realmName, "stormwind", 1),
				Namespace: namespace,
			}, &deploy)
			Expect(err).NotTo(HaveOccurred())

			gracePeriod := deploy.Spec.Template.Spec.TerminationGracePeriodSeconds
			Expect(gracePeriod).NotTo(BeNil())
			Expect(*gracePeriod).To(Equal(int64(120)))
		})

		It("should add a readiness probe to the zone container", func() {
			controllerReconciler := &RealmReconciler{
				Client: k8sClient,
				Scheme: k8sClient.Scheme(),
			}

			_, err := controllerReconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: types.NamespacedName{Name: realmName, Namespace: namespace},
			})
			Expect(err).NotTo(HaveOccurred())

			var deploy appsv1.Deployment
			err = k8sClient.Get(ctx, types.NamespacedName{
				Name:      zoneDeploymentName(realmName, "elwynn-forest", 1),
				Namespace: namespace,
			}, &deploy)
			Expect(err).NotTo(HaveOccurred())

			probe := deploy.Spec.Template.Spec.Containers[0].ReadinessProbe
			Expect(probe).NotTo(BeNil())
			Expect(probe.HTTPGet).NotTo(BeNil())
			Expect(probe.HTTPGet.Path).To(Equal("/readyz"))
			Expect(probe.HTTPGet.Port).To(Equal(intstr.FromInt32(8080)))
		})
	})
})

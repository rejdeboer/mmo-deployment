package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type RealmSpec struct {
	// zoneSetRef is the name of the ZoneSet resource that defines the zones for this realm
	// +required
	ZoneSetRef string `json:"zoneSetRef"`

	// template is the base pod template for zone server pods.
	// Per-zone resource overrides from the ZoneSet will be applied on top.
	// +required
	Template corev1.PodTemplateSpec `json:"template"`
}

// LayerStatus represents the observed state of a single layer within a zone
type LayerStatus struct {
	// layer is the layer number (1-indexed)
	Layer int32 `json:"layer"`

	// address is the node IP where this layer's pod is running
	// +optional
	Address string `json:"address,omitempty"`

	// port is the hostPort this layer is exposed on
	// +optional
	Port int32 `json:"port,omitempty"`

	// phase is the current phase of the layer's pod (Pending, Running, Failed, etc.)
	// +optional
	Phase corev1.PodPhase `json:"phase,omitempty"`

	// playerCount is the current number of players in this layer
	// +optional
	PlayerCount int32 `json:"playerCount,omitempty"`
}

// ZoneStatus represents the observed state of a single zone within a realm
type ZoneStatus struct {
	// name is the zone name
	Name string `json:"name"`

	// layers contains the status of each active layer for this zone
	// +listType=map
	// +listMapKey=layer
	// +optional
	Layers []LayerStatus `json:"layers,omitempty"`
}

// RealmStatus defines the observed state of Realm.
type RealmStatus struct {
	// zones contains the status of each zone in the realm
	// +listType=map
	// +listMapKey=name
	// +optional
	Zones []ZoneStatus `json:"zones,omitempty"`

	// conditions represent the current state of the Realm resource.
	// +listType=map
	// +listMapKey=type
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Zones",type=integer,JSONPath=`.status.zones[*]`,description="Number of zones"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// Realm is the Schema for the realms API.
// It represents a single game realm (e.g. "Stormrage") composed of multiple zones.
type Realm struct {
	metav1.TypeMeta `json:",inline"`

	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty,omitzero"`

	// +required
	Spec RealmSpec `json:"spec"`

	// +optional
	Status RealmStatus `json:"status,omitempty,omitzero"`
}

// +kubebuilder:object:root=true

// RealmList contains a list of Realm
type RealmList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Realm `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Realm{}, &RealmList{})
}

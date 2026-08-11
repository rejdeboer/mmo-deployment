package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type ZoneSpec struct {
	// name is the unique identifier for this zone (e.g. "elwynn-forest", "stormwind")
	// +required
	Name string `json:"name"`

	// port is the host port this zone's game server is exposed on.
	// Must be unique across all zones in the cluster to avoid scheduling conflicts.
	// +required
	Port int32 `json:"port"`

	// resources defines the resource requirements for this zone's pod
	// +optional
	Resources corev1.ResourceRequirements `json:"resources,omitempty"`

	// playerCap is the maximum number of players allowed in this zone
	// +optional
	PlayerCap *int32 `json:"playerCap,omitempty"`

	// maxLayers is the maximum number of concurrent layers (instances) of this zone.
	// When player count approaches playerCap, the operator can spin up additional layers.
	// Defaults to 1 (no layering).
	// +optional
	// +kubebuilder:default=1
	// +kubebuilder:validation:Minimum=1
	MaxLayers *int32 `json:"maxLayers,omitempty"`
}

type ZoneSetSpec struct {
	// zones is the list of zone definitions
	// +required
	// +listType=map
	// +listMapKey=name
	Zones []ZoneSpec `json:"zones"`
}

// ZoneSetStatus defines the observed state of ZoneSet.
type ZoneSetStatus struct {
	// conditions represent the current state of the ZoneSet resource.
	// +listType=map
	// +listMapKey=type
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// ZoneSet is the Schema for the zonesets API.
// It defines a set of zones that make up a game world.
type ZoneSet struct {
	metav1.TypeMeta `json:",inline"`

	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty,omitzero"`

	// +required
	Spec ZoneSetSpec `json:"spec"`

	// +optional
	Status ZoneSetStatus `json:"status,omitempty,omitzero"`
}

// +kubebuilder:object:root=true

// ZoneSetList contains a list of ZoneSet
type ZoneSetList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ZoneSet `json:"items"`
}

func init() {
	SchemeBuilder.Register(&ZoneSet{}, &ZoneSetList{})
}

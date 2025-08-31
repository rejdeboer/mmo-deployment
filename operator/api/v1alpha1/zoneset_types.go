package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type ZoneSpec struct {
	// +required
	Name *string `json:"name"`
}

type ZoneSetSpec struct {
	// +required
	Zones []ZoneSpec `json:"zones"`
}

// ZoneSetStatus defines the observed state of ZoneSet.
type ZoneSetStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// For Kubernetes API conventions, see:
	// https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#typical-status-properties

	// conditions represent the current state of the ZoneSet resource.
	// Each condition has a unique type and reflects the status of a specific aspect of the resource.
	//
	// Standard condition types include:
	// - "Available": the resource is fully functional
	// - "Progressing": the resource is being created or updated
	// - "Degraded": the resource failed to reach or maintain its desired state
	//
	// The status of each condition is one of True, False, or Unknown.
	// +listType=map
	// +listMapKey=type
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// ZoneSet is the Schema for the zonesets API
type ZoneSet struct {
	metav1.TypeMeta `json:",inline"`

	// metadata is a standard object metadata
	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty,omitzero"`

	// spec defines the desired state of ZoneSet
	// +required
	Spec ZoneSetSpec `json:"spec"`

	// status defines the observed state of ZoneSet
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

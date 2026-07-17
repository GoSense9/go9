package platform

import "testing"

func TestStatus(t *testing.T) {
	st, err := NewProvider().Status()
	if err != nil {
		t.Fatal(err)
	}
	if st.Product != "GoSense9" || st.Component != "go9" || st.PID == 0 || st.OS == "" {
		t.Fatalf("bad status: %+v", st)
	}
}

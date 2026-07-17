package bootstrap

import "testing"

func TestParseRoles(t *testing.T) {
	for _, r := range []Role{RoleInit, RoleControl, RoleConsole, RoleWeb} {
		c, err := Parse([]string{"--role=" + string(r)})
		if err != nil || c.Role != r {
			t.Fatalf("role %s got %v %v", r, c, err)
		}
	}
}
func TestParseBadRole(t *testing.T) {
	if _, err := Parse([]string{"--role=bad"}); err == nil {
		t.Fatal("expected error")
	}
}

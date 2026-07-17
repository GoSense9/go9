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
func TestParseDefaults(t *testing.T) {
	c, err := Parse(nil)
	if err != nil {
		t.Fatal(err)
	}
	if c.WebAddr != "127.0.0.1:8080" {
		t.Fatalf("web addr = %q", c.WebAddr)
	}
	if !c.Console {
		t.Fatal("console should default enabled")
	}
}
func TestParseConsoleFalse(t *testing.T) {
	c, err := Parse([]string{"--role=init", "--console=false"})
	if err != nil {
		t.Fatal(err)
	}
	if c.Console {
		t.Fatal("console should be disabled")
	}
}

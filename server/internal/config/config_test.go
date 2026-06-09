package config

import "testing"

func TestNormalizeEnvDefaults(t *testing.T) {
	cases := []struct {
		env        string
		wantPrefix string
		wantApple  string
		wantStrict bool
	}{
		{"dev", "ss:dev:", "Sandbox", false},
		{"test", "ss:test:", "Sandbox", true},
		{"prod", "ss:prod:", "Production", true},
	}
	for _, tc := range cases {
		t.Setenv("APP_ENV", tc.env)
		// Ensure no overrides leak between cases.
		t.Setenv("REDIS_KEY_PREFIX", "")
		t.Setenv("APPLE_ENVIRONMENT", "")
		t.Setenv("STRICT_APPLE_ENV", "")
		c := Load()
		if c.RedisKeyPrefix != tc.wantPrefix {
			t.Errorf("env=%s prefix=%q want %q", tc.env, c.RedisKeyPrefix, tc.wantPrefix)
		}
		if c.AppleEnvironment != tc.wantApple {
			t.Errorf("env=%s apple=%q want %q", tc.env, c.AppleEnvironment, tc.wantApple)
		}
		if c.StrictAppleEnv != tc.wantStrict {
			t.Errorf("env=%s strict=%v want %v", tc.env, c.StrictAppleEnv, tc.wantStrict)
		}
	}
}

func TestInvalidEnvPanics(t *testing.T) {
	defer func() {
		if recover() == nil {
			t.Fatal("expected panic for invalid APP_ENV")
		}
	}()
	t.Setenv("APP_ENV", "staging")
	_ = Load()
}

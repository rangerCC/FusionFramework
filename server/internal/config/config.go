package config

import (
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all runtime configuration, loaded from environment variables.
// Secrets (DB password, JWT secret, Apple keys, Aliyun AK/SK) must come from
// the environment / a secret manager — never hard-coded.
type Config struct {
	Env  string // dev | prod
	Port string

	// Postgres
	DatabaseURL string // postgres://user:pass@host:5432/db?sslmode=disable

	// Redis
	RedisAddr     string
	RedisPassword string
	RedisDB       int

	// JWT
	JWTSecret       string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration

	// SMS
	SMSDevMode      bool   // when true, accept fixed code, do not call provider
	SMSDevCode      string // fixed code in dev (default 1234)
	AliyunSMSKey    string
	AliyunSMSSecret string
	SMSSignName     string
	SMSTemplateCode string

	// OSS
	OSSEndpoint   string
	OSSBucket     string
	OSSAccessKey  string
	OSSSecret     string
	OSSPublicHost string // CDN host for public_url

	// App Store
	AppleBundleID       string
	AppleIssuerID       string
	AppleKeyID          string
	ApplePrivateKeyPath string // .p8 for App Store Server API
	MonthlyFreeQuota    int

	// CORS / misc
	AllowedOrigins []string

	// --- environment isolation ---
	// RedisKeyPrefix namespaces all Redis keys by environment so a shared Redis
	// instance can't leak SMS codes / rate-limit counters across environments.
	RedisKeyPrefix string
	// AppleEnvironment is the App Store environment this deployment trusts:
	// "Sandbox" (test) or "Production" (prod).
	AppleEnvironment string
	// StrictAppleEnv rejects transactions whose environment != AppleEnvironment,
	// so a sandbox purchase can never grant an entitlement in production (and vice versa).
	StrictAppleEnv bool
}

func Load() *Config {
	c := &Config{
		Env:                 getenv("APP_ENV", "dev"),
		Port:                getenv("PORT", "8080"),
		DatabaseURL:         getenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/socialstory?sslmode=disable"),
		RedisAddr:           getenv("REDIS_ADDR", "localhost:6379"),
		RedisPassword:       getenv("REDIS_PASSWORD", ""),
		RedisDB:             getenvInt("REDIS_DB", 0),
		JWTSecret:           getenv("JWT_SECRET", "dev-insecure-change-me"),
		AccessTokenTTL:      time.Duration(getenvInt("ACCESS_TTL_SEC", 7200)) * time.Second,
		RefreshTokenTTL:     time.Duration(getenvInt("REFRESH_TTL_SEC", 2592000)) * time.Second,
		SMSDevMode:          getenvBool("SMS_DEV_MODE", true),
		SMSDevCode:          getenv("SMS_DEV_CODE", "1234"),
		AliyunSMSKey:        getenv("ALIYUN_SMS_KEY", ""),
		AliyunSMSSecret:     getenv("ALIYUN_SMS_SECRET", ""),
		SMSSignName:         getenv("SMS_SIGN_NAME", ""),
		SMSTemplateCode:     getenv("SMS_TEMPLATE_CODE", ""),
		OSSEndpoint:         getenv("OSS_ENDPOINT", ""),
		OSSBucket:           getenv("OSS_BUCKET", ""),
		OSSAccessKey:        getenv("OSS_ACCESS_KEY", ""),
		OSSSecret:           getenv("OSS_SECRET", ""),
		OSSPublicHost:       getenv("OSS_PUBLIC_HOST", ""),
		AppleBundleID:       getenv("APPLE_BUNDLE_ID", "com.alitrip.socialstory"),
		AppleIssuerID:       getenv("APPLE_ISSUER_ID", ""),
		AppleKeyID:          getenv("APPLE_KEY_ID", ""),
		ApplePrivateKeyPath: getenv("APPLE_PRIVATE_KEY_PATH", ""),
		MonthlyFreeQuota:    getenvInt("MONTHLY_FREE_QUOTA", 3),
		AllowedOrigins:      strings.Split(getenv("ALLOWED_ORIGINS", "*"), ","),
	}
	c.normalizeEnv()
	return c
}

// validEnvs are the only accepted APP_ENV values. Anything else is a misconfig
// and we refuse to guess — this prevents an unset/typo'd env silently behaving
// like production (or sharing prod's isolation namespace).
var validEnvs = map[string]bool{"dev": true, "test": true, "prod": true}

// normalizeEnv derives isolation defaults from APP_ENV and validates it.
func (c *Config) normalizeEnv() {
	if !validEnvs[c.Env] {
		panic("invalid APP_ENV '" + c.Env + "': must be one of dev|test|prod")
	}
	// Redis key prefix defaults to "ss:<env>:" unless explicitly overridden.
	c.RedisKeyPrefix = getenv("REDIS_KEY_PREFIX", "ss:"+c.Env+":")

	// App Store environment: prod trusts Production, everything else Sandbox,
	// unless explicitly set. Strict matching is on by default outside dev.
	defApple := "Sandbox"
	if c.Env == "prod" {
		defApple = "Production"
	}
	c.AppleEnvironment = getenv("APPLE_ENVIRONMENT", defApple)
	c.StrictAppleEnv = getenvBool("STRICT_APPLE_ENV", c.Env != "dev")
}

func (c *Config) IsDev() bool  { return c.Env == "dev" }
func (c *Config) IsProd() bool { return c.Env == "prod" }

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func getenvInt(k string, def int) int {
	if v := os.Getenv(k); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func getenvBool(k string, def bool) bool {
	if v := os.Getenv(k); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return def
}

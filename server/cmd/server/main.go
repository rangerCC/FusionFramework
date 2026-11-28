package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/alitrip/socialstory-server/internal/admin"
	"github.com/alitrip/socialstory-server/internal/config"
	"github.com/alitrip/socialstory-server/internal/device"
	"github.com/alitrip/socialstory-server/internal/platform/appstore"
	"github.com/alitrip/socialstory-server/internal/platform/db"
	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/idgen"
	"github.com/alitrip/socialstory-server/internal/platform/jwtx"
	"github.com/alitrip/socialstory-server/internal/stories"
	"github.com/alitrip/socialstory-server/internal/subscription"
)

func main() {
	cfg := config.Load()
	ctx := context.Background()

	// --- infrastructure ---
	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("db: %v", err)
	}
	defer pool.Close()

	// Refuse to start if DB was previously stamped with a different environment.
	if err := db.GuardEnvironment(ctx, pool, cfg.Env); err != nil {
		log.Fatalf("env guard: %v", err)
	}

	if dir := os.Getenv("MIGRATIONS_DIR"); dir != "" {
		if err := db.RunMigrations(ctx, pool, dir); err != nil {
			log.Fatalf("migrate: %v", err)
		}
	}

	ids := idgen.NewSnowflake(1)

	// jwtx is still needed by admin login/auth.
	jwtMgr := jwtx.New(cfg.JWTSecret, cfg.AccessTokenTTL)

	// Apple verifier — required by subscription service.
	appleVerifier := &appstore.DefaultVerifier{
		BundleID: cfg.AppleBundleID, IssuerID: cfg.AppleIssuerID,
		KeyID: cfg.AppleKeyID, PrivateKeyPath: cfg.ApplePrivateKeyPath,
	}

	// --- module wiring ---
	deviceH := device.NewHandler(pool, ids)

	subSvc := subscription.NewService(pool, ids, appleVerifier, cfg.AppleEnvironment, cfg.StrictAppleEnv)
	subH := subscription.NewHandler(subSvc)

	// admin: pass nil for usage.AdminOps — quota endpoints are disabled in PoC.
	adminH := admin.NewHandler(pool, ids, jwtMgr, nil)

	storiesH := stories.NewHandler(pool, ids)

	// --- router ---
	if !cfg.IsDev() {
		gin.SetMode(gin.ReleaseMode)
	}
	r := gin.New()
	r.Use(httpx.RequestID(), httpx.Recovery(), httpx.CORS(cfg.AllowedOrigins))

	r.GET("/healthz", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"status": "ok"}) })

	v1 := r.Group("/v1")

	// public
	deviceH.Register(v1)        // POST /v1/device/register
	subH.RegisterPublic(v1)     // Apple webhook
	adminH.RegisterPublic(v1)   // admin login
	storiesH.RegisterPublic(v1) // featured stories list (ETag-cached)

	// authed (device-identity)
	authed := v1.Group("")
	authed.Use(deviceH.DeviceRequired())
	subH.RegisterAuthed(authed)
	subH.RegisterDeviceAuthed(authed)

	// admin (admin JWT)
	adminG := v1.Group("")
	adminG.Use(adminH.AdminAuth())
	adminH.RegisterAuthed(adminG)
	storiesH.RegisterAdmin(adminG)

	// --- serve with graceful shutdown ---
	srv := &http.Server{Addr: ":" + cfg.Port, Handler: r}
	go func() {
		log.Printf("listening on :%s (env=%s, apple_env=%s, strict_apple=%v)",
			cfg.Port, cfg.Env, cfg.AppleEnvironment, cfg.StrictAppleEnv)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("serve: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down...")
	shctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shctx)
}

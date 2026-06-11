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

	"github.com/alitrip/socialstory-server/internal/account"
	"github.com/alitrip/socialstory-server/internal/admin"
	"github.com/alitrip/socialstory-server/internal/auth"
	"github.com/alitrip/socialstory-server/internal/children"
	"github.com/alitrip/socialstory-server/internal/config"
	"github.com/alitrip/socialstory-server/internal/platform/appstore"
	"github.com/alitrip/socialstory-server/internal/platform/db"
	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/idgen"
	"github.com/alitrip/socialstory-server/internal/platform/jwtx"
	"github.com/alitrip/socialstory-server/internal/platform/oss"
	"github.com/alitrip/socialstory-server/internal/platform/redisx"
	"github.com/alitrip/socialstory-server/internal/platform/sms"
	"github.com/alitrip/socialstory-server/internal/subscription"
	"github.com/alitrip/socialstory-server/internal/usage"
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

	// Bind this database to APP_ENV. Refuses to start if the DB was previously
	// stamped with a different environment (e.g. test pointed at prod).
	if err := db.GuardEnvironment(ctx, pool, cfg.Env); err != nil {
		log.Fatalf("env guard: %v", err)
	}

	if dir := os.Getenv("MIGRATIONS_DIR"); dir != "" {
		if err := db.RunMigrations(ctx, pool, dir); err != nil {
			log.Fatalf("migrate: %v", err)
		}
	}

	rdb, err := redisx.New(cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB, cfg.RedisKeyPrefix)
	if err != nil {
		log.Fatalf("redis: %v", err)
	}

	ids := idgen.NewSnowflake(1)
	jwtMgr := jwtx.New(cfg.JWTSecret, cfg.AccessTokenTTL)

	// --- platform adapters ---
	var smsSender sms.Sender = sms.DevSender{}
	if !cfg.SMSDevMode {
		smsSender = &sms.AliyunSender{
			AccessKey: cfg.AliyunSMSKey, AccessSecret: cfg.AliyunSMSSecret,
			SignName: cfg.SMSSignName, TemplateCode: cfg.SMSTemplateCode,
		}
	}
	ossSigner := oss.AliyunSigner{
		Endpoint: cfg.OSSEndpoint, Bucket: cfg.OSSBucket,
		AccessKey: cfg.OSSAccessKey, Secret: cfg.OSSSecret, PublicHost: cfg.OSSPublicHost,
	}
	appleVerifier := &appstore.DefaultVerifier{
		BundleID: cfg.AppleBundleID, IssuerID: cfg.AppleIssuerID,
		KeyID: cfg.AppleKeyID, PrivateKeyPath: cfg.ApplePrivateKeyPath,
	}

	// --- module wiring ---
	authSvc := auth.NewService(cfg, pool, rdb, ids, jwtMgr, smsSender)
	authH := auth.NewHandler(authSvc)
	accountH := account.NewHandler(pool, ossSigner)
	childrenH := children.NewHandler(pool, ids)
	subSvc := subscription.NewService(pool, ids, appleVerifier, cfg.AppleEnvironment, cfg.StrictAppleEnv)
	subH := subscription.NewHandler(subSvc)
	usageH := usage.NewHandler(pool, subSvc, cfg.MonthlyFreeQuota) // subSvc implements SubChecker
	adminOps := usage.NewAdminOps(pool, cfg.MonthlyFreeQuota)
	adminH := admin.NewHandler(pool, ids, jwtMgr, adminOps)

	// --- router ---
	if !cfg.IsDev() {
		gin.SetMode(gin.ReleaseMode)
	}
	r := gin.New()
	r.Use(httpx.RequestID(), httpx.Recovery(), httpx.CORS(cfg.AllowedOrigins))

	r.GET("/healthz", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"status": "ok"}) })

	v1 := r.Group("/v1")

	// public
	authH.Register(v1)
	subH.RegisterPublic(v1)   // Apple webhook
	adminH.RegisterPublic(v1) // admin login

	// authed (app user)
	authed := v1.Group("")
	authed.Use(auth.AuthRequired(jwtMgr))
	authH.RegisterAuthed(authed)
	accountH.Register(authed)
	childrenH.Register(authed)
	subH.RegisterAuthed(authed)
	usageH.Register(authed)

	// admin (admin token)
	adminG := v1.Group("")
	adminG.Use(adminH.AdminAuth())
	adminH.RegisterAuthed(adminG)

	// --- serve with graceful shutdown ---
	srv := &http.Server{Addr: ":" + cfg.Port, Handler: r}
	go func() {
		log.Printf("listening on :%s (env=%s, redis_prefix=%q, apple_env=%s, strict_apple=%v)",
			cfg.Port, cfg.Env, cfg.RedisKeyPrefix, cfg.AppleEnvironment, cfg.StrictAppleEnv)
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

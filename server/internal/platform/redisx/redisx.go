package redisx

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

// Client wraps go-redis with the small set of operations the app needs.
// All keys are transparently namespaced with prefix so multiple environments
// can share a Redis instance without colliding.
type Client struct {
	rdb    *redis.Client
	prefix string
}

func New(addr, password string, dbIndex int, prefix string) (*Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       dbIndex,
	})
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, err
	}
	return &Client{rdb: rdb, prefix: prefix}, nil
}

// k applies the environment namespace to a key.
func (c *Client) k(key string) string { return c.prefix + key }

func (c *Client) Set(ctx context.Context, key, val string, ttl time.Duration) error {
	return c.rdb.Set(ctx, c.k(key), val, ttl).Err()
}

func (c *Client) Get(ctx context.Context, key string) (string, error) {
	return c.rdb.Get(ctx, c.k(key)).Result()
}

func (c *Client) Del(ctx context.Context, key string) error {
	return c.rdb.Del(ctx, c.k(key)).Err()
}

func (c *Client) Exists(ctx context.Context, key string) (bool, error) {
	n, err := c.rdb.Exists(ctx, c.k(key)).Result()
	return n > 0, err
}

// Incr increments a key and sets its TTL on first creation. Returns new value.
func (c *Client) Incr(ctx context.Context, key string, ttl time.Duration) (int64, error) {
	pk := c.k(key)
	n, err := c.rdb.Incr(ctx, pk).Result()
	if err != nil {
		return 0, err
	}
	if n == 1 {
		_ = c.rdb.Expire(ctx, pk, ttl).Err()
	}
	return n, nil
}

// TTL returns remaining ttl for a key.
func (c *Client) TTL(ctx context.Context, key string) (time.Duration, error) {
	return c.rdb.TTL(ctx, c.k(key)).Result()
}

// IsNil reports whether err is redis.Nil (key missing).
func IsNil(err error) bool { return err == redis.Nil }

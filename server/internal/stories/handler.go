package stories

import (
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

// Handler serves featured-story endpoints.
type Handler struct {
	repo *repo
}

func NewHandler(pool *pgxpool.Pool, ids *idgen.Snowflake) *Handler {
	return &Handler{repo: &repo{pool: pool, ids: ids}}
}

// RegisterPublic mounts the public list endpoint (no auth).
func (h *Handler) RegisterPublic(r *gin.RouterGroup) {
	r.GET("/featured-stories", h.list)
}

// RegisterAdmin mounts admin-only management endpoints (behind admin auth).
func (h *Handler) RegisterAdmin(r *gin.RouterGroup) {
	r.GET("/admin/featured-stories", h.adminList)
	r.POST("/admin/featured-stories", h.create)
	r.DELETE("/admin/featured-stories/:id", h.delete)
}

// adminList returns the full featured list for management (no ETag/304),
// including sort weight so the dashboard can show/curate order.
func (h *Handler) adminList(c *gin.Context) {
	list, err := h.repo.listAll(c.Request.Context())
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	items := make([]gin.H, 0, len(list))
	for _, s := range list {
		items = append(items, gin.H{
			"story_id":   s.PublicID,
			"title":      s.Title,
			"image_url":  s.ImageURL,
			"word_count": s.WordCount,
			"sort":       s.Sort,
			"created_at": s.CreatedAt,
			"raw":        json.RawMessage(s.RawJSON), // full coze JSON for the detail view
		})
	}
	httpx.OK(c, gin.H{"items": items, "total": len(items)})
}

// list returns all featured stories, with ETag-based change detection.
// If the client's If-None-Match matches the current list ETag, returns 304
// (the app then keeps its locally cached copy).
func (h *Handler) list(c *gin.Context) {
	ctx := c.Request.Context()
	etag, err := h.repo.etag(ctx)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if match := c.GetHeader("If-None-Match"); match != "" && match == etag {
		c.Header("ETag", etag)
		c.Status(http.StatusNotModified)
		return
	}
	list, err := h.repo.listAll(ctx)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	items := make([]gin.H, 0, len(list))
	for _, s := range list {
		items = append(items, gin.H{
			"story_id":   s.PublicID,
			"title":      s.Title,
			"image_url":  s.ImageURL,
			"word_count": s.WordCount,
			"created_at": s.CreatedAt,
			"raw":        json.RawMessage(s.RawJSON), // full coze JSON, embedded as-is
		})
	}
	c.Header("ETag", etag)
	httpx.OK(c, gin.H{"etag": etag, "stories": items})
}

// createReq accepts the full coze story JSON plus an optional sort weight.
type createReq struct {
	Sort int             `json:"sort"`
	Raw  json.RawMessage `json:"raw"`
}

func (h *Handler) create(c *gin.Context) {
	var req createReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	if len(req.Raw) == 0 {
		httpx.Fail(c, httpx.ErrStoryBadFormat)
		return
	}
	// Extract the columns we index/display from the raw payload.
	title, imageURL, wordCount, ok := extractFields(req.Raw)
	if !ok {
		httpx.Fail(c, httpx.ErrStoryBadFormat)
		return
	}
	s, err := h.repo.insert(c.Request.Context(), insertInput{
		Title: title, ImageURL: imageURL, WordCount: wordCount,
		RawJSON: req.Raw, Sort: req.Sort,
	})
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, gin.H{"story_id": s.PublicID, "title": s.Title})
}

func (h *Handler) delete(c *gin.Context) {
	ok, err := h.repo.deleteByPublicID(c.Request.Context(), c.Param("id"))
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if !ok {
		httpx.Fail(c, httpx.ErrStoryNotFound)
		return
	}
	httpx.OK(c, nil)
}

// extractFields pulls title / first-page image / word count from a coze story
// JSON object. Returns ok=false if the payload isn't a usable story.
func extractFields(raw json.RawMessage) (title, imageURL string, wordCount int, ok bool) {
	var doc struct {
		StoryTitle string `json:"story_title"`
		Pages      []struct {
			Content         string `json:"content"`
			IllustrationURL string `json:"illustration_url"`
		} `json:"pages"`
	}
	if err := json.Unmarshal(raw, &doc); err != nil {
		return "", "", 0, false
	}
	if doc.StoryTitle == "" || len(doc.Pages) == 0 {
		return "", "", 0, false
	}
	for _, p := range doc.Pages {
		wordCount += len([]rune(p.Content))
	}
	return doc.StoryTitle, doc.Pages[0].IllustrationURL, wordCount, true
}

package children

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

// Handler serves child-profile endpoints (all require auth).
type Handler struct {
	repo *repo
}

func NewHandler(pool *pgxpool.Pool, ids *idgen.Snowflake) *Handler {
	return &Handler{repo: &repo{pool: pool, ids: ids}}
}

func (h *Handler) Register(r *gin.RouterGroup) {
	r.GET("/children", h.list)
	r.POST("/children", h.create)
	r.PUT("/children/:id", h.update)
	r.DELETE("/children/:id", h.delete)
	r.POST("/children/:id/default", h.setDefault)
}

var validGender = map[string]bool{"boy": true, "girl": true}
var validDiagnosis = map[string]bool{"asd": true, "adhd": true, "social_anxiety": true, "other": true}
var validLevel = map[string]bool{"simple": true, "moderate": true, "advanced": true}

func childJSON(c Child) gin.H {
	interests := c.Interests
	if interests == nil {
		interests = []string{}
	}
	return gin.H{
		"child_id":       c.PublicID,
		"name":           c.Name,
		"gender":         c.Gender,
		"birthday":       c.Birthday.Format("2006-01-02"),
		"age":            ageFromBirthday(c.Birthday),
		"diagnosis_type": c.DiagnosisType,
		"language_level": c.LanguageLevel,
		"interests":      interests,
		"avatar_url":     c.AvatarURL,
		"is_default":     c.IsDefault,
		"created_at":     c.CreatedAt,
		"updated_at":     c.UpdatedAt,
	}
}

func ageFromBirthday(b time.Time) int {
	now := time.Now()
	age := now.Year() - b.Year()
	if now.YearDay() < b.YearDay() {
		age--
	}
	if age < 0 {
		age = 0
	}
	return age
}

func (h *Handler) list(c *gin.Context) {
	items, err := h.repo.list(c.Request.Context(), httpx.UserID(c))
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	arr := []gin.H{}
	for _, ch := range items {
		arr = append(arr, childJSON(ch))
	}
	httpx.OK(c, gin.H{"children": arr})
}

// createReq mirrors the documented body (all required on create).
type createReq struct {
	Name          string   `json:"name"`
	Gender        string   `json:"gender"`
	Birthday      string   `json:"birthday"`
	DiagnosisType string   `json:"diagnosis_type"`
	LanguageLevel string   `json:"language_level"`
	Interests     []string `json:"interests"`
}

func (h *Handler) create(c *gin.Context) {
	var req createReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	bday, ok := parseBirthday(req.Birthday)
	if req.Name == "" || !validGender[req.Gender] || !validDiagnosis[req.DiagnosisType] ||
		!validLevel[req.LanguageLevel] || !ok {
		httpx.Fail(c, httpx.ErrChildIncomplete)
		return
	}
	uid := httpx.UserID(c)
	n, err := h.repo.count(c.Request.Context(), uid)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if n >= maxChildren {
		httpx.Fail(c, httpx.ErrChildTooMany)
		return
	}
	ch, err := h.repo.create(c.Request.Context(), uid, childInput{
		Name: &req.Name, Gender: &req.Gender, Birthday: &bday,
		DiagnosisType: &req.DiagnosisType, LanguageLevel: &req.LanguageLevel, Interests: req.Interests,
	})
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	// First child of the account becomes the default automatically.
	if n == 0 {
		if ok, derr := h.repo.setDefault(c.Request.Context(), uid, ch.PublicID); derr == nil && ok {
			ch.IsDefault = true
		}
	}
	httpx.OK(c, gin.H{"child": childJSON(*ch)})
}

func (h *Handler) setDefault(c *gin.Context) {
	ok, err := h.repo.setDefault(c.Request.Context(), httpx.UserID(c), c.Param("id"))
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if !ok {
		httpx.Fail(c, httpx.ErrChildNotFound)
		return
	}
	httpx.OK(c, nil)
}

// updateReq has all-optional fields for partial update.
type updateReq struct {
	Name          *string  `json:"name"`
	Gender        *string  `json:"gender"`
	Birthday      *string  `json:"birthday"`
	DiagnosisType *string  `json:"diagnosis_type"`
	LanguageLevel *string  `json:"language_level"`
	Interests     []string `json:"interests"`
}

func (h *Handler) update(c *gin.Context) {
	var req updateReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	in := childInput{Name: req.Name, Gender: req.Gender,
		DiagnosisType: req.DiagnosisType, LanguageLevel: req.LanguageLevel, Interests: req.Interests}
	if req.Gender != nil && !validGender[*req.Gender] {
		httpx.Fail(c, httpx.ErrBadParam)
		return
	}
	if req.DiagnosisType != nil && !validDiagnosis[*req.DiagnosisType] {
		httpx.Fail(c, httpx.ErrBadParam)
		return
	}
	if req.LanguageLevel != nil && !validLevel[*req.LanguageLevel] {
		httpx.Fail(c, httpx.ErrBadParam)
		return
	}
	if req.Birthday != nil {
		bday, ok := parseBirthday(*req.Birthday)
		if !ok {
			httpx.Fail(c, httpx.ErrBadParam)
			return
		}
		in.Birthday = &bday
	}
	ch, err := h.repo.update(c.Request.Context(), httpx.UserID(c), c.Param("id"), in)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if ch == nil {
		httpx.Fail(c, httpx.ErrChildNotFound)
		return
	}
	httpx.OK(c, gin.H{"child": childJSON(*ch)})
}

func (h *Handler) delete(c *gin.Context) {
	ok, err := h.repo.softDelete(c.Request.Context(), httpx.UserID(c), c.Param("id"))
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if !ok {
		httpx.Fail(c, httpx.ErrChildNotFound)
		return
	}
	httpx.OK(c, nil)
}

func parseBirthday(s string) (time.Time, bool) {
	t, err := time.Parse("2006-01-02", s)
	if err != nil || t.After(time.Now()) {
		return time.Time{}, false
	}
	age := ageFromBirthday(t)
	if age < 2 || age > 16 {
		return time.Time{}, false
	}
	return t, true
}

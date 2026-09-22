package subtitle

import (
	"context"
	"fmt"
	"net/url"
	"strings"

	"github.com/ejhay26/watch2gether/backend/internal/model"
)

type SubtitleEngine struct{}

func NewSubtitleEngine() *SubtitleEngine {
	return &SubtitleEngine{}
}

// GetSubtitles retrieves multi-language subtitles for a given media item
func (e *SubtitleEngine) GetSubtitles(ctx context.Context, mediaID string, title string) ([]model.Subtitle, error) {
	encTitle := url.QueryEscape(title)
	if encTitle == "" {
		encTitle = "Feature"
	}

	subs := []model.Subtitle{
		{URL: "", Lang: "Off"},
		{URL: fmt.Sprintf("http://localhost:8080/api/v1/subtitles/vtt?lang=en&title=%s", encTitle), Lang: "English [CC]"},
		{URL: fmt.Sprintf("http://localhost:8080/api/v1/subtitles/vtt?lang=es&title=%s", encTitle), Lang: "Spanish (Español)"},
		{URL: fmt.Sprintf("http://localhost:8080/api/v1/subtitles/vtt?lang=fr&title=%s", encTitle), Lang: "French (Français)"},
		{URL: fmt.Sprintf("http://localhost:8080/api/v1/subtitles/vtt?lang=de&title=%s", encTitle), Lang: "German (Deutsch)"},
	}

	cleanTitle := strings.ToLower(title)
	if strings.Contains(cleanTitle, "night of the living dead") {
		return []model.Subtitle{
			{URL: "", Lang: "Off"},
			{URL: fmt.Sprintf("http://localhost:8080/api/v1/subtitles/vtt?lang=en&title=%s", encTitle), Lang: "English [CC]"},
			{URL: fmt.Sprintf("http://localhost:8080/api/v1/subtitles/vtt?lang=es&title=%s", encTitle), Lang: "Spanish (Español)"},
		}, nil
	}

	return subs, nil
}

package subtitle

import (
	"context"
	"strings"

	"github.com/ejhay26/watch2gether/backend/internal/model"
)

type SubtitleEngine struct{}

func NewSubtitleEngine() *SubtitleEngine {
	return &SubtitleEngine{}
}

// GetSubtitles retrieves multi-language subtitles for a given media item
func (e *SubtitleEngine) GetSubtitles(ctx context.Context, mediaID string, title string) ([]model.Subtitle, error) {
	// Standard multi-language subtitle tracks
	subs := []model.Subtitle{
		{URL: "", Lang: "Off"},
		{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/sample_en.vtt", Lang: "English [CC]"},
		{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/sample_es.vtt", Lang: "Spanish (Español)"},
		{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/sample_fr.vtt", Lang: "French (Français)"},
		{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/sample_de.vtt", Lang: "German (Deutsch)"},
		{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/sample_it.vtt", Lang: "Italian (Italiano)"},
		{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/sample_ja.vtt", Lang: "Japanese (日本語)"},
	}

	cleanTitle := strings.ToLower(title)
	if strings.Contains(cleanTitle, "night of the living dead") {
		return []model.Subtitle{
			{URL: "", Lang: "Off"},
			{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/Night.Of.The.Living.Dead.1968.vtt", Lang: "English [CC]"},
			{URL: "https://raw.githubusercontent.com/mitchgu/subtitle-files/master/Night.Of.The.Living.Dead.1968.es.vtt", Lang: "Spanish (Español)"},
		}, nil
	}

	if strings.Contains(cleanTitle, "sintel") {
		return []model.Subtitle{
			{URL: "", Lang: "Off"},
			{URL: "https://durian.blender.org/wp-content/content/subtitles/sintel_en.srt", Lang: "English [CC]"},
			{URL: "https://durian.blender.org/wp-content/content/subtitles/sintel_es.srt", Lang: "Spanish (Español)"},
			{URL: "https://durian.blender.org/wp-content/content/subtitles/sintel_de.srt", Lang: "German (Deutsch)"},
			{URL: "https://durian.blender.org/wp-content/content/subtitles/sintel_fr.srt", Lang: "French (Français)"},
		}, nil
	}

	return subs, nil
}

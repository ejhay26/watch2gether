package audio

type AudioTrackInfo struct {
	ID       string `json:"id"`
	Language string `json:"language"`
	Title    string `json:"title"`
	Channels string `json:"channels,omitempty"`
}

type AudioEngine struct{}

func NewAudioEngine() *AudioEngine {
	return &AudioEngine{}
}

func (e *AudioEngine) FormatTrackLabel(index int, lang string, title string, channels string) string {
	if title != "" && title != "Track" {
		return title
	}

	displayLang := "Audio"
	if lang != "" {
		switch lang {
		case "en", "eng":
			displayLang = "English"
		case "es", "spa":
			displayLang = "Spanish"
		case "fr", "fra", "fre":
			displayLang = "French"
		case "de", "deu", "ger":
			displayLang = "German"
		case "ja", "jpn":
			displayLang = "Japanese"
		case "it", "ita":
			displayLang = "Italian"
		case "pt", "por":
			displayLang = "Portuguese"
		default:
			displayLang = lang
		}
	}

	chanStr := ""
	if channels != "" {
		chanStr = " [" + channels + "]"
	}

	return "Track " + string(rune('1'+index)) + ": " + displayLang + chanStr
}

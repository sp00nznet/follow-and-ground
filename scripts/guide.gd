# Every word the guide says lives here, so anyone (ideally a licensed EMDR clinician) can review it in one place.
class_name Guide

const DISCLAIMER := "This is a practice and grounding tool. It is not therapy or a medical device, and it does not diagnose or treat any condition, including PTSD. It does not replace a trained clinician. Work only with mild, everyday memories, nothing traumatic. You choose what to bring up and how far to go. You can press Stop / Ground me (Esc) at any time, and stopping is always fine. If you feel unsafe, or you're thinking about harming yourself, please reach out now."
const CRISIS := [["US: call or text 988 (Suicide & Crisis Lifeline)", "tel:988"], ["Outside the US: findahelpline.com", "https://findahelpline.com"]]

const LINES := {
	"safePlace": [
		"Let's start by finding a calm place. It can be real or imagined.",
		"If you like, let your eyes soften or close.",
		"Notice what you see there. The colors, the light.",
		"Notice any sounds, or the quiet.",
		"What does the air feel like on your skin?",
		"Notice where in your body you feel at ease.",
		"If a word fits this place, you can give it one. You can come back here any time.",
	],
	"target": [
		"When you're ready, and only if you want to, pick a small memory that bothers you a little.",
		"Choose something mild, like a two to five out of ten. Keep the heavy ones for a therapist.",
		"Let it come to mind gently. You don't need every detail.",
		"Notice the picture that stands for it.",
		"Notice any thought that comes with it, like \"I'm ...\"",
		"Notice what you feel, and where it sits in your body.",
		"From 0 to 10, how upsetting does it feel right now?",
	],
	"setIntro": [
		"Follow the object with your eyes, or just let it be there.",
		"Let whatever comes up come up. There's no right way to do this.",
	],
	"setOutro": [
		"Let it go, and take a breath.",
		"Notice what comes up. A thought, an image, a feeling, or nothing at all.",
		"From 0 to 10, how upsetting does it feel now?",
	],
	"highSud": [
		"That feels like a lot right now. That's okay.",
		"Would you like to ground for a moment, or keep going?",
	],
	"closing": [
		"Let's come back to the here and now.",
		"Name 5 things you can see.",
		"4 things you can touch or feel.",
		"3 things you can hear.",
		"2 things you can smell.",
		"1 thing you can taste, or one kind thing you can say to yourself.",
		"Breathe in for 4.",
		"Hold for 4.",
		"Breathe out for 6.",
		"Again, in for 4, hold, and out for 6.",
		"If you like, go back to your calm place for a moment.",
	],
	"end": [
		"Thank you for taking this time.",
		"Things may keep shifting for a while. That's normal. Be gentle with yourself today.",
		"If something stays heavy, talk to someone you trust or a professional. The crisis lines are always below.",
	],
}

const TUNING := {
	"hz": 1.0, "width": 0.8, "set_seconds": 25.0, "sets_max": 12,
	"line_pause": 1.5, "question_pause": 3.0, "high_sud": 8,
}

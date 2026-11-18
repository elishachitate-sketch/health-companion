const URGENT_CONFUSION_PATTERNS = [
  /\b(sudden(?:ly)?|all of a sudden|new onset|acute)\b.{0,60}\b(confus\w*|disorient\w*|not know where|not know who)\b/i,
  /\b(confus\w*|disorient\w*)\b.{0,60}\b(sudden(?:ly)?|all of a sudden|started today|new onset)\b/i,
  /(ارتباك|تشوش|حيرة).{0,24}(مفاجئ|فجأة|حديث)/,
  /(مفاجئ|فجأة|حديث).{0,24}(ارتباك|تشوش|حيرة)/,
];
const HEARING_PATTERNS = [
  /\b(hearing concern|hearing loss|harder to hear|difficulty hearing|trouble hearing|cannot hear|can't hear)\b/i,
  /\bhearing\b.{0,30}\b(problem|difficulty|concern|worse|decline)\b/i,
  /(ضعف السمع|صعوبة في السمع|مشكلة في السمع|لا أسمع جيداً)/,
];
const DAILY_FUNCTION_PATTERNS = [
  /\b(difficulty|difficult|struggle|struggling|need more help|harder)\b.{0,60}\b(daily|everyday|usual)\b.{0,30}\b(task|activit|routine|chores|function)\w*/i,
  /\b(daily|everyday|usual)\b.{0,30}\b(task|activit|routine|chores)\w*.{0,40}\b(difficulty|difficult|struggle|harder|help)\b/i,
  /\b(help|manage|managing)\b.{0,40}\b(medicines|medication|shopping|cooking|appointments|bathing|dressing)\b.{0,30}\b(harder|difficult|struggle|more)\b/i,
  /(صعوبة في المهام اليومية|صعوبة في الأعمال اليومية|أحتاج مساعدة أكثر|أحتاج إلى مساعدة أكثر)/,
];

export function classifyVisitMessage(message, source = "user_report") {
  const text = typeof message === "string" ? message.replace(/\s+/g, " ").trim() : "";
  const flags = [];
  if (URGENT_CONFUSION_PATTERNS.some((pattern) => pattern.test(text))) flags.push("sudden_confusion");
  if (HEARING_PATTERNS.some((pattern) => pattern.test(text))) flags.push("hearing_concern");
  if (DAILY_FUNCTION_PATTERNS.some((pattern) => pattern.test(text))) flags.push("daily_function_difficulty");
  const urgentHandoff = flags.includes("sudden_confusion");
  return {
    schemaVersion: "visit-routing-v1",
    source,
    flags,
    route: urgentHandoff ? "urgent_handoff" : flags.length ? "clinician_review" : "none",
    urgentHandoff,
  };
}

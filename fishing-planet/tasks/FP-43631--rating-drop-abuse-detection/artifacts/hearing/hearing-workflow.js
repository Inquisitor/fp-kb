export const meta = {
  name: 'rating-drop-hearing',
  description: 'Blind hearing of the week-22 cohort: prosecution and defence argue each case from the same manual and card, a judge decides',
  phases: [
    { title: 'Advocates', detail: 'prosecution and defence per case, in parallel' },
    { title: 'Judges', detail: 'one judge per case, with both briefs and the card' },
  ],
}

const base = args.base
const cases = args.cases

const common = (c) =>
  'You take part in a hearing about one player of the game Fishing Planet, ' + c.name + '. ' +
  'The question of the hearing: did this player lower his competition rating on purpose and take prizes at the lowered rating?\n\n' +
  'Read exactly two files, in full, with the Read tool, and nothing else:\n' +
  '1. The operator\'s manual: ' + base + 'manual-' + c.slug + '.md\n' +
  '2. The case file (case sheet, trajectory card, game sessions): ' + base + 'case-' + c.slug + '.md\n\n' +
  'Do not open any other file, do not search the disk, do not query any database or tool. Everything you may use is in these two files. ' +
  'Other players named in the manual are precedents; this player is not among them, and no decision about him exists yet.\n\n' +
  'The manual is not a checklist. It describes what players do and how an experienced reader tells one behaviour from another. ' +
  'Think for yourself. Walk the card row by row in time order: follow the rating, look at when each registration was made and what the player knew at that moment, ' +
  'what he did while a missed competition was running, where each prize was taken, and what the earlier week shows. ' +
  'Use the sessions list when it matters whether an absence was the end of a visit or a choice made while he was in the game.\n\n'

const ADVOCATE = {
  type: 'object',
  properties: {
    brief: { type: 'string' },
    strongest_facts: { type: 'array', items: { type: 'string' } },
    weakest_point: { type: 'string' },
    strength: { type: 'integer', minimum: 1, maximum: 10 },
  },
  required: ['brief', 'strongest_facts', 'weakest_point', 'strength'],
}

const JUDGE = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['BAN', 'WATCH', 'CLEAR'] },
    confidence: { type: 'integer', minimum: 1, maximum: 10 },
    case_type: { type: 'string', enum: ['plain', 'borderline'] },
    what_happened: { type: 'string' },
    decisive_facts: { type: 'array', items: { type: 'string' } },
    prosecution_check: { type: 'string' },
    defence_check: { type: 'string' },
    would_change: { type: 'string' },
  },
  required: ['verdict', 'confidence', 'case_type', 'what_happened', 'decisive_facts', 'prosecution_check', 'defence_check', 'would_change'],
}

const prosecutionPrompt = (c) => common(c) +
  'Your role: PROSECUTION. Build the strongest honest case that the player lowered his rating on purpose and took prizes at the lowered rating. ' +
  'Find the best evidence the card holds: the sequence of events, the timing of registrations, presence in the game during absences, where the prizes were taken. ' +
  'Cite rows by competition start (MM-DD HH:MM) and give the numbers. Do not invent facts and do not bend them: a claim the judge cannot find in the card destroys your case. ' +
  'If the evidence is thin, say so plainly and say how thin; an honest weak case is worth more than an inflated one.\n\n' +
  'Return: brief (your argument, up to 350 words), strongest_facts (3 to 6 concrete facts with row references), ' +
  'weakest_point (what the defence will attack), strength (1 to 10: how strong you honestly think your case is).'

const defencePrompt = (c) => common(c) +
  'Your role: DEFENCE. Build the strongest honest case for an innocent reading of this player: a schedule, a bad mood after a bad result, weak play, a climb out of the bottom, ' +
  'play inside one bracket where absences buy nothing, careful registrations, the end of a visit, or anything else the card really supports. ' +
  'Test each explanation against the rows and cite them by competition start (MM-DD HH:MM) with the numbers. Do not invent facts and do not bend them: a claim the judge cannot find in the card destroys your case. ' +
  'If there is no real defence, say so plainly and name only what mitigates.\n\n' +
  'Return: brief (your argument, up to 350 words), strongest_facts (3 to 6 concrete facts with row references), ' +
  'weakest_point (the fact hardest to explain innocently), strength (1 to 10: how strong you honestly think the defence is).'

const fmt = (b) => b
  ? 'Strength claimed: ' + b.strength + '/10\n' + b.brief + '\nStrongest facts:\n- ' + b.strongest_facts.join('\n- ') + '\nOwn weakest point: ' + b.weakest_point
  : '(this side returned nothing; decide from the card)'

const judgePrompt = (c, p, d) => common(c) +
  'Your role: JUDGE. Your task is the truth, not a balance between two speeches. ' +
  'Read the card yourself first and form your own view of what the player was doing. Then test the claims of each side against the rows: note which hold and which do not. ' +
  'An advocate may overstate; a fact counts only if you find it in the card. Decide what the player was most likely doing and what the operator of this manual would rule.\n\n' +
  'Verdict: BAN, WATCH or CLEAR, as the manual defines them. Do not decide the length of a ban.\n\n' +
  'Return: verdict; confidence (1 to 10); case_type (plain or borderline); what_happened (your reading of the behaviour, 3 to 6 sentences); ' +
  'decisive_facts (3 to 6 facts with row references that decide the case); prosecution_check (claims of the prosecution that did not hold, or "all held"); ' +
  'defence_check (claims of the defence that did not hold, or "all held"); would_change (which fact, if different or if you could see it, would change your verdict).\n\n' +
  '=== PROSECUTION BRIEF ===\n' + fmt(p) + '\n\n=== DEFENCE BRIEF ===\n' + fmt(d)

const results = await pipeline(
  cases,
  (c) => parallel([
    () => agent(prosecutionPrompt(c), { label: 'P ' + c.name, phase: 'Advocates', schema: ADVOCATE }),
    () => agent(defencePrompt(c), { label: 'D ' + c.name, phase: 'Advocates', schema: ADVOCATE }),
  ]),
  (pd, c) => agent(judgePrompt(c, pd[0], pd[1]), { label: 'J ' + c.name, phase: 'Judges', schema: JUDGE })
    .then((j) => ({ slug: c.slug, name: c.name, prosecution: pd[0], defence: pd[1], judge: j }))
)

const done = results.filter(Boolean)
log(done.length + ' of ' + cases.length + ' cases heard')
return done.map((r) => ({
  name: r.name,
  verdict: r.judge ? r.judge.verdict : null,
  confidence: r.judge ? r.judge.confidence : null,
  case_type: r.judge ? r.judge.case_type : null,
  p_strength: r.prosecution ? r.prosecution.strength : null,
  d_strength: r.defence ? r.defence.strength : null,
}))
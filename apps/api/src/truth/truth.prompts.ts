export type TruthPrompt = { level: number; text: string };

/** 本地固定题库（后续可按亲密度解锁层级；AI 出题另接） */
export const TRUTH_PROMPTS: TruthPrompt[] = [
  { level: 1, text: '今天最想对对方说的一句话是什么？' },
  { level: 1, text: '最近一次因为对方开心，是因为什么？' },
  { level: 1, text: '你眼中对方最可爱的一个小习惯是？' },
  { level: 1, text: '这周最想一起做的一件小事是什么？' },
  { level: 1, text: '对方做过让你觉得被照顾到的一件事？' },
  { level: 1, text: '用三个词形容现在的你们。' },
  { level: 1, text: '你更喜欢对方认真的样子，还是开玩笑的样子？为什么？' },
  { level: 1, text: '今天有没有一件事想夸夸对方？' },
  { level: 2, text: '有什么小事，其实很希望对方能经常做？' },
  { level: 2, text: '吵架或冷战时，你最希望对方怎么对待你？' },
  { level: 2, text: '你在这段关系里最有安全感的瞬间是？' },
  { level: 2, text: '有什么关于你的事，对方可能还不太了解？' },
  { level: 2, text: '如果明天只能陪对方两小时，你想怎么过？' },
  { level: 2, text: '你最想被对方记住的一个「你」是什么样的？' },
  { level: 2, text: '最近有没有对对方感到一点点亏欠？想说吗？' },
  { level: 3, text: '你对这段关系最深的一个担心是什么？' },
  { level: 3, text: '如果可以重来第一次见面，你会想改哪一句开场白？' },
  { level: 3, text: '你理想中一年后的「我们」是什么样子？' },
  { level: 3, text: '有什么话一直想说但还没说出口？' },
  { level: 3, text: '在对方面前，你最不想被看穿的一面是什么？' },
];

export function pickPrompt(level?: number, exclude: string[] = []): TruthPrompt {
  const pool = TRUTH_PROMPTS.filter(
    (p) => (level == null || p.level <= level) && !exclude.includes(p.text),
  );
  const source = pool.length > 0 ? pool : TRUTH_PROMPTS;
  return source[Math.floor(Math.random() * source.length)];
}

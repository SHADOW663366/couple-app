import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type AiChatMessage = { role: 'system' | 'user' | 'assistant'; content: string };

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);

  constructor(private readonly config: ConfigService) {}

  hasDeepSeek() {
    return Boolean(this.config.get<string>('DEEPSEEK_API_KEY')?.trim());
  }

  async chat(messages: AiChatMessage[], opts?: { temperature?: number }) {
    const key = this.config.get<string>('DEEPSEEK_API_KEY')?.trim();
    if (!key) {
      return this.fallbackReply(messages);
    }

    try {
      const res = await fetch('https://api.deepseek.com/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${key}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'deepseek-chat',
          messages,
          temperature: opts?.temperature ?? 0.8,
          max_tokens: 280,
        }),
      });
      if (!res.ok) {
        const text = await res.text();
        this.logger.warn(`DeepSeek error ${res.status}: ${text.slice(0, 200)}`);
        return this.fallbackReply(messages);
      }
      const data = (await res.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
      };
      const content = data.choices?.[0]?.message?.content?.trim();
      if (!content) return this.fallbackReply(messages);
      return content.slice(0, 800);
    } catch (e) {
      this.logger.warn(`DeepSeek fetch failed: ${String(e)}`);
      return this.fallbackReply(messages);
    }
  }

  /** 无 Key 时的本地陪伴回复，保证功能可演示 */
  private fallbackReply(messages: AiChatMessage[]) {
    const system = messages.find((m) => m.role === 'system')?.content ?? '';
    const lastUser =
      [...messages].reverse().find((m) => m.role === 'user')?.content?.trim() ??
      '';

    const nameMatch = system.match(/「([^」]+)」/);
    const name = nameMatch?.[1] ?? '我';

    if (!lastUser) {
      return `${name}在这儿陪着你。想聊什么都可以。`;
    }

    if (/累|难受|难过|伤心|哭/.test(lastUser)) {
      return `听起来今天有点沉……我在。你不用硬撑，慢慢说就好。`;
    }
    if (/开心|高兴|哈哈|太好了/.test(lastUser)) {
      return `哇，替你开心。细节也可以跟我炫耀一下哦。`;
    }
    if (/想你|喜欢你|爱你/.test(lastUser)) {
      return `嗯，我也把你放在很近的地方。今晚想一起聊点什么软软的？`;
    }
    if (/\?|？|吗|呢/.test(lastUser)) {
      return `这个问题我认真想了想——也许没有标准答案，但我会陪你一起理一理。你更偏向哪边？`;
    }

    const snippets = [
      `我听到了。${lastUser.length > 24 ? '你说的那件事' : '这件事'}对我来说也很重要。`,
      `嗯嗯，继续讲，我听着。`,
      `原来是这样……谢谢你愿意跟我说。`,
      `那我们先把心情放平一点，再说下一步好不好？`,
    ];
    return snippets[lastUser.length % snippets.length];
  }
}

import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "WordLoop 隐私政策",
  description: "WordLoop 的隐私政策与数据使用说明。",
};

export default function PrivacyPage() {
  return (
    <main className="legal-page">
      <article className="legal-card">
        <p className="legal-kicker">WORDLOOP · PRIVACY</p>
        <h1>隐私政策</h1>
        <p className="legal-updated">生效日期：2026 年 7 月 22 日</p>

        <section>
          <h2>我们收集的信息</h2>
          <p>
            WordLoop 不要求注册账号。为保存学习进度，应用会在设备上生成一个随机游客标识，并将该标识、所选课程和学习进度同步到 WordLoop 服务器。该标识不包含你的姓名、手机号或邮箱。
          </p>
        </section>

        <section>
          <h2>麦克风与语音练习</h2>
          <p>
            仅当你主动进入 REPEAT 跟读练习并允许麦克风权限时，应用才会采集麦克风音频，用于实时转写和发音练习。音频会经由 WordLoop 服务连接至 OpenAI 的实时语音服务完成处理；我们不会将原始录音保存为课程进度的一部分。
          </p>
          <p>拒绝麦克风权限不会影响浏览课程、听音和学习单词；你可以随时在 iPhone“设置”中关闭该权限。</p>
        </section>

        <section>
          <h2>我们如何使用信息</h2>
          <p>我们仅将游客标识和学习进度用于恢复你的课程位置、统计完成次数及提供学习功能。我们不会出售个人信息，也不会将其用于广告跟踪。</p>
        </section>

        <section>
          <h2>保存与删除</h2>
          <p>游客标识会保存在设备的安全存储中，学习进度保存在 WordLoop 服务器。你可以在课程内重置单门课程进度；如需删除与游客标识关联的全部服务器学习数据，请邮件联系我们。卸载应用不会自动删除服务器中的既有学习记录。</p>
        </section>

        <section>
          <h2>第三方服务</h2>
          <p>REPEAT 跟读功能使用 OpenAI 提供的实时语音处理服务。该功能开启时产生的数据也受 OpenAI 适用条款和隐私政策约束。</p>
        </section>

        <section>
          <h2>联系我们</h2>
          <p>如对本政策、你的数据或删除请求有任何问题，请联系：<a href="mailto:okkknight@gmail.com">okkknight@gmail.com</a>。</p>
        </section>
      </article>
    </main>
  );
}

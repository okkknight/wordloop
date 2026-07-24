import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "WordLoop 支持",
  description: "WordLoop 使用帮助与联系方式。",
};

export default function SupportPage() {
  return (
    <main className="legal-page">
      <article className="legal-card">
        <p className="legal-kicker">WORDLOOP · SUPPORT</p>
        <h1>WordLoop 支持</h1>
        <p>WordLoop 是一款英语听辨、跟读与词汇练习应用。当前版本可使用游客模式直接开始学习，无需注册。</p>

        <section>
          <h2>麦克风无法使用？</h2>
          <p>REPEAT 跟读需要麦克风权限。请前往 iPhone“设置”→“WordLoop”→开启“麦克风”，然后重新进入 REPEAT。</p>
        </section>

        <section>
          <h2>学习进度</h2>
          <p>学习进度会与当前设备的游客标识同步。你可以在课程中重置单门课程进度；如需删除全部数据，请打开“学习进度”侧栏，选择“删除全部学习数据”。该操作会同时删除本机与服务器中的当前游客学习记录，并生成新的游客标识。</p>
        </section>

        <section>
          <h2>反馈与联系</h2>
          <p>请将问题、建议、设备型号和 iOS 版本发送至：<a href="mailto:okkknight@gmail.com">okkknight@gmail.com</a>。</p>
        </section>

        <p className="legal-links"><a href="../privacy">查看隐私政策</a></p>
      </article>
    </main>
  );
}

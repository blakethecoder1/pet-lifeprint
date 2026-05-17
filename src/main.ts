import { NUI, isDebug } from './nui';
import '../styles.css';

const app = document.getElementById('app')!;
let visible = isDebug;

function render(): void {
  if (!visible) {
    app.innerHTML = '';
    return;
  }

  app.innerHTML = `
    <div class="w-screen h-screen flex items-center justify-center">
      <main class="w-[600px] max-w-[90vw] bg-zinc-900/90 border border-zinc-700 rounded-lg shadow-2xl p-6">
        <div class="flex items-center justify-between mb-4">
          <h1 class="text-white text-xl font-semibold">My Panel</h1>
          <button id="close-btn" class="text-zinc-400 hover:text-white transition-colors text-lg leading-none">\u2715</button>
        </div>
        <p class="text-zinc-400 text-sm">Your NUI is ready. Start building!</p>
      </main>
    </div>
  `;

  document.getElementById('close-btn')!.addEventListener('click', handleClose);
}

function handleClose(): void {
  visible = false;
  render();
  NUI.request('close', {}, { success: true });
}

NUI.on('open', () => {
  visible = true;
  render();
});

NUI.on('close', () => {
  visible = false;
  render();
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && visible) handleClose();
});

render();

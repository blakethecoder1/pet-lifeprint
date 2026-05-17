var i=typeof window.GetParentResourceName==="function",m=i?window.GetParentResourceName():"bldr-resource",a=!i;if(a)document.body.style.background="rgba(0, 0, 0, 0.6)";var s={async request(e,n={},t){if(!i&&t!==void 0)return console.log(`[NUI Dev] ${e}:`,t),t;if(!i)return console.warn(`[NUI Dev] No mock for '${e}'. Pass mockData as 3rd arg.`),{};return(await fetch(`https://${m}/${e}`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(n)})).json()},on(e,n){let t=(d)=>{let r=d.data;if(typeof r==="string")try{r=JSON.parse(r)}catch{}let{action:b,data:w}=r??{};if(b===e)n(w??{})};return window.addEventListener("message",t),()=>window.removeEventListener("message",t)},close(e={success:!0}){return this.request("close",{},e)},emit(e,n){window.dispatchEvent(new MessageEvent("message",{data:{action:e,data:n}}))}};if(a)setTimeout(()=>s.emit("open",{}),100);var l=document.getElementById("app"),o=a;function c(){if(!o){l.innerHTML="";return}l.innerHTML=`
    <div class="w-screen h-screen flex items-center justify-center">
      <main class="w-[600px] max-w-[90vw] bg-zinc-900/90 border border-zinc-700 rounded-lg shadow-2xl p-6">
        <div class="flex items-center justify-between mb-4">
          <h1 class="text-white text-xl font-semibold">My Panel</h1>
          <button id="close-btn" class="text-zinc-400 hover:text-white transition-colors text-lg leading-none">✕</button>
        </div>
        <p class="text-zinc-400 text-sm">Your NUI is ready. Start building!</p>
      </main>
    </div>
  `,document.getElementById("close-btn").addEventListener("click",u)}function u(){o=!1,c(),s.request("close",{},{success:!0})}s.on("open",()=>{o=!0,c()});s.on("close",()=>{o=!1,c()});document.addEventListener("keydown",(e)=>{if(e.key==="Escape"&&o)u()});c();

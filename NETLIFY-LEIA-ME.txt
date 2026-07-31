<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#09090b">
  <title>Acompanhar pedido — Code Forge</title><link rel="icon" href="favicon.svg" type="image/svg+xml"><link rel="stylesheet" href="tracking.css"><script src="tracking.js" defer></script>
</head>
<body>
  <main>
    <a class="brand" href="index.html"><img src="assets/brand/logo-code-forge.jpeg" alt="Code Forge"><span><b>Code Forge</b><small>Pedidos</small></span></a>
    <section class="tracking-card">
      <p class="eyebrow">ACOMPANHAMENTO</p><h1>Veja onde está seu pedido.</h1><p class="lead">Informe o código recebido na finalização e o mesmo telefone utilizado no pedido.</p>
      <form id="trackingForm"><label><span>Código do pedido</span><input name="code" placeholder="CF-0000-0000" required></label><label><span>Telefone</span><input name="phone" inputmode="tel" placeholder="(79) 99999-9999" required></label><button>Consultar pedido</button></form>
      <div id="trackingResult" class="result hidden"></div>
    </section>
  </main>
</body>
</html>

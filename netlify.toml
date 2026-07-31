<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  <meta name="theme-color" content="#0b0b0d">
  <meta name="description" content="Demonstração full-stack de pedidos da Code Forge Restaurante e Lanches.">
  <title>Code Forge Pedidos — Restaurante e Lanches</title>
  <link rel="icon" href="favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="styles.css">
  <script src="app.js" defer></script>
</head>
<body>
  <a class="skip-link" href="#catalogo">Ir para o cardápio</a>
  <div class="toast-region" id="toastRegion" aria-live="polite"></div>

  <header class="site-header" id="siteHeader">
    <a class="brand" href="#topo" aria-label="Code Forge Pedidos">
      <img src="assets/brand/logo-code-forge.jpeg" alt="Code Forge">
      <span><b>Code Forge</b><small>Pedidos inteligentes</small></span>
    </a>
    <nav class="header-actions" aria-label="Ações">
      <button class="ghost-btn" id="accountButton" type="button">Minha conta</button>
      <a class="ghost-btn desktop-only" href="acompanhar.html">Acompanhar pedido</a>
      <button class="cart-button" id="cartButton" type="button" aria-label="Abrir carrinho">
        <span>Carrinho</span><b id="cartCount">0</b>
      </button>
    </nav>
  </header>

  <main id="topo">
    <section class="hero">
      <div class="hero-grid">
        <div class="hero-copy">
          <p class="eyebrow">DEMONSTRAÇÃO FULL-STACK • CODE FORGE</p>
          <h1>Seu pedido, do cardápio ao painel.</h1>
          <p class="hero-lead">Escolha a operação, monte cada item com adicionais, finalize com cálculo validado no servidor e acompanhe o pedido em tempo real.</p>
          <div class="trust-row">
            <span>✓ Preço recalculado no back-end</span>
            <span>✓ Estoque real por produto</span>
            <span>✓ Pedido salvo antes do WhatsApp</span>
          </div>
        </div>
        <div class="hero-mark" aria-hidden="true">
          <div class="forge-symbol">CF</div>
          <div class="pulse-ring"></div>
        </div>
      </div>

      <div class="store-choice" aria-labelledby="choiceTitle">
        <div class="choice-head">
          <p class="eyebrow">ESCOLHA SUA EXPERIÊNCIA</p>
          <h2 id="choiceTitle">O que você quer pedir hoje?</h2>
        </div>
        <div class="choice-grid">
          <button class="store-card active" type="button" data-store="restaurant">
            <span class="store-index">01</span>
            <span class="store-content"><b>Code Forge Restaurante</b><small>Pratos e marmitas do almoço</small></span>
            <span class="store-status" data-store-status="restaurant">Carregando…</span>
          </button>
          <button class="store-card" type="button" data-store="snacks">
            <span class="store-index">02</span>
            <span class="store-content"><b>Code Forge Lanches</b><small>Sanduíches, pratos rápidos e marmitas</small></span>
            <span class="store-status" data-store-status="snacks">Carregando…</span>
          </button>
        </div>
      </div>
    </section>

    <section class="catalog-section" id="catalogo">
      <div class="catalog-head">
        <div>
          <p class="eyebrow" id="currentStoreEyebrow">CODE FORGE RESTAURANTE</p>
          <h2 id="catalogTitle">Cardápio do almoço</h2>
          <p id="storeReason" class="muted"></p>
        </div>
        <div class="search-wrap">
          <label for="searchInput">Buscar no cardápio</label>
          <input id="searchInput" type="search" placeholder="Ex.: feijoada, frango…" autocomplete="off">
        </div>
      </div>
      <div class="category-tabs" id="categoryTabs" aria-label="Categorias"></div>
      <div class="product-grid" id="productGrid" aria-live="polite"></div>
      <div class="empty-state hidden" id="emptyState">
        <b>Nenhum produto encontrado.</b>
        <span>Tente outro termo ou categoria.</span>
      </div>
    </section>

    <section class="system-section">
      <div>
        <p class="eyebrow">POR TRÁS DA EXPERIÊNCIA</p>
        <h2>O navegador monta. O servidor confere.</h2>
      </div>
      <div class="system-flow">
        <article><span>01</span><b>Cliente escolhe</b><p>Produtos, quantidades, adicionais e observações.</p></article>
        <article><span>02</span><b>Back-end valida</b><p>Preços, regras obrigatórias, horário e estoque são recalculados.</p></article>
        <article><span>03</span><b>Pedido é salvo</b><p>O sistema gera um código, reduz o estoque e registra no painel.</p></article>
        <article><span>04</span><b>WhatsApp abre</b><p>O cliente segue para a conversa, mas o valor oficial já está salvo.</p></article>
      </div>
      <div class="system-links">
        <a class="primary-btn" href="admin.html">Ver painel administrativo</a>
        <a class="secondary-btn" href="acompanhar.html">Acompanhar um pedido</a>
      </div>
    </section>
  </main>

  <aside class="drawer" id="cartDrawer" aria-hidden="true" aria-labelledby="cartTitle">
    <div class="drawer-backdrop" data-close-cart></div>
    <section class="drawer-panel">
      <header><div><p class="eyebrow">SEU PEDIDO</p><h2 id="cartTitle">Carrinho</h2></div><button class="icon-btn" type="button" data-close-cart aria-label="Fechar carrinho">×</button></header>
      <div class="cart-items" id="cartItems"></div>
      <div class="cart-summary">
        <div><span>Subtotal</span><b id="cartSubtotal">R$ 0,00</b></div>
        <small>O valor final será recalculado no servidor.</small>
        <button class="primary-btn full" id="checkoutButton" type="button">Continuar</button>
      </div>
    </section>
  </aside>

  <dialog class="product-dialog" id="productDialog">
    <form method="dialog" class="dialog-shell" id="productForm">
      <button class="dialog-close" value="cancel" aria-label="Fechar">×</button>
      <div class="dialog-image-wrap"><img id="dialogImage" src="" alt=""></div>
      <div class="dialog-content">
        <p class="eyebrow" id="dialogCategory"></p>
        <h2 id="dialogName"></h2>
        <p id="dialogDescription" class="muted"></p>
        <div class="price-line"><strong id="dialogPrice"></strong><del id="dialogOldPrice"></del></div>
        <div id="optionGroups"></div>
        <label class="field-block"><span>Alguma observação?</span><textarea id="itemNote" maxlength="140" rows="3" placeholder="Ex.: tirar cebola, molho separado…"></textarea><small><span id="noteCount">0</span>/140</small></label>
        <div class="quantity-total"><div class="qty-control"><button type="button" id="qtyMinus" aria-label="Diminuir">−</button><b id="qtyValue">1</b><button type="button" id="qtyPlus" aria-label="Aumentar">+</button></div><div><small>Total do item</small><strong id="itemTotal"></strong></div></div>
        <button class="primary-btn full" type="submit" value="default" id="addToCartButton">Adicionar ao carrinho</button>
      </div>
    </form>
  </dialog>

  <dialog class="checkout-dialog" id="checkoutDialog">
    <form method="dialog" class="checkout-shell" id="checkoutForm">
      <button class="dialog-close" value="cancel" aria-label="Fechar">×</button>
      <div>
        <p class="eyebrow">FINALIZAÇÃO SEGURA</p>
        <h2>Dados do pedido</h2>
        <p class="muted">O pedido será salvo no painel antes de você seguir para o WhatsApp.</p>
      </div>
      <div class="form-grid">
        <label><span>Nome completo</span><input name="name" required minlength="2" maxlength="80" autocomplete="name"></label>
        <label><span>WhatsApp</span><input name="phone" required inputmode="tel" placeholder="(79) 99999-9999" autocomplete="tel"></label>
      </div>
      <fieldset class="choice-fieldset"><legend>Como deseja receber?</legend><label><input type="radio" name="fulfillment" value="pickup" checked> Retirada</label><label><input type="radio" name="fulfillment" value="delivery"> Entrega</label></fieldset>
      <label class="hidden" id="addressField"><span>Endereço completo</span><input name="address" maxlength="180" autocomplete="street-address"></label>
      <label><span>Forma de pagamento</span><select name="paymentMethod"><option>Pix pelo WhatsApp</option><option>Dinheiro</option><option>Cartão na entrega/retirada</option><option>Combinar pelo WhatsApp</option></select></label>
      <div class="checkout-total"><span>Total estimado</span><strong id="checkoutTotal"></strong><small>O servidor recalculará o valor e a taxa de entrega.</small></div>
      <button class="primary-btn full" type="submit" value="default" id="finalizeButton">Salvar pedido e abrir WhatsApp</button>
    </form>
  </dialog>

  <dialog class="account-dialog" id="accountDialog">
    <div class="account-shell">
      <button class="dialog-close" type="button" id="accountClose" aria-label="Fechar">×</button>
      <div id="accountGuest">
        <p class="eyebrow">CONTA OPCIONAL</p><h2>Entre ou crie sua conta</h2><p class="muted">Você também pode comprar sem cadastro. A conta serve para ver seu histórico.</p>
        <div class="account-tabs"><button class="active" type="button" data-account-tab="login">Entrar</button><button type="button" data-account-tab="register">Criar conta</button></div>
        <form id="loginForm" class="account-form"><label><span>E-mail</span><input name="email" type="email" required></label><label><span>Senha</span><input name="password" type="password" required></label><button class="primary-btn full">Entrar</button></form>
        <form id="registerForm" class="account-form hidden"><label><span>Nome</span><input name="name" required></label><label><span>E-mail</span><input name="email" type="email" required></label><label><span>Telefone</span><input name="phone" required></label><label><span>Senha</span><input name="password" type="password" minlength="8" required></label><button class="primary-btn full">Criar conta</button></form>
      </div>
      <div id="accountLogged" class="hidden"><p class="eyebrow">MINHA CONTA</p><h2 id="accountName"></h2><p id="accountEmail" class="muted"></p><div id="myOrders" class="my-orders"></div><button class="secondary-btn full" id="logoutButton" type="button">Sair da conta</button></div>
    </div>
  </dialog>

  <footer class="site-footer"><div><img src="assets/brand/logo-code-forge.jpeg" alt="Code Forge"><p>Demonstração de sistema de pedidos com front-end, back-end, estoque e painel administrativo.</p></div><div><a href="admin.html">Painel</a><a href="acompanhar.html">Acompanhar pedido</a><span>WhatsApp: (79) 99860-5321</span></div></footer>
</body>
</html>

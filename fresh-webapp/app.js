/* FoodieNoms fresh demo — plain browser JavaScript, no build tools required. */
(() => {
  'use strict';
  const store = FoodieData.createStore();
  const root = document.querySelector('#app');
  let session = null;
  let route = { name: 'start', data: null };
  let backStack = [];
  let category = 'All';
  let searchText = '';
  let priceLimit = 3000;
  let pickedRole = null;
  let noticeTimer;
  const $ = selector => document.querySelector(selector);
  const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money = cents => 'RM ' + (cents / 100).toFixed(2);
  const time = value => { const [h,m] = value.split(':').map(Number); return (h % 12 || 12) + (m ? ':' + String(m).padStart(2,'0') : '') + (h >= 12 ? ' PM' : ' AM'); };
  const pickup = food => time(food.pickupStart) + ' – ' + time(food.pickupEnd);
  const vendor = id => store.state.vendors.find(v => v.id === id);
  const food = id => store.state.listings.find(l => l.id === id);
  const order = id => store.state.orders.find(o => o.id === id);
  const icon = name => `<img src="./assets/icons/${name}.svg" class="icon" alt="" aria-hidden="true">`;
  const action = (text, name, css = 'primary', attrs = '') => `<button type="button" class="button ${css}" data-action="${name}" ${attrs}>${text}</button>`;
  const status = value => `<span class="status status-${escape(value)}">${escape(value)}</span>`;
  const field = (label,name,type='text',value='',attrs='') => `<label class="field"><span>${label}</span><input type="${type}" name="${name}" value="${escape(value)}" ${attrs}></label>`;
  const blank = (title, text) => `<section class="empty-state">${icon('heart')}<h2>${title}</h2><p>${text}</p></section>`;
  const photo = (listing, css='') => `<div class="food-photo photo-${escape(listing.image || 'bakery')} ${css}" role="img" aria-label="Illustrative ${escape(listing.name)} photograph"></div>`;
  function notify(text) {
    $('#notice').textContent = text;
    $('#notice').classList.add('visible');
    clearTimeout(noticeTimer);
    noticeTimer = setTimeout(() => $('#notice').classList.remove('visible'), 3400);
  }
  function navigate(name, data = null, replace = false) {
    if (!replace) backStack.push(route);
    route = {name,data};
    render();
  }
  function goBack() { route = backStack.pop() || {name:session ? home() : 'start',data:null}; render(); }
  function home() { return session?.role === 'admin' ? 'admin' : session?.role === 'vendor' ? 'vendor' : 'discover'; }
  function logout() { session = null; backStack = []; route = {name:'start',data:null}; category='All'; searchText=''; render(); }
  function login(role) { session = {role}; backStack = []; navigate(home(),null,true); }
  function pageTitle(title, subtitle='') { return `<div class="page-heading"><h1>${title}</h1>${subtitle ? `<p>${subtitle}</p>` : ''}</div>`; }
  function intro() {
    return `<div class="entry-page"><main class="entry-card"><img class="entry-logo" src="./assets/logo.png" alt="FoodieNoms food rescue logo"><h1>FoodieNoms</h1><p class="entry-tagline">Eat good. Save more.</p><p class="eyebrow">GOOD FOOD. A BETTER TOMORROW.</p><h2>A little rescue.<br>A lot to love.</h2><p class="entry-description">Fresh finds from your neighbourhood, at a price that feels good.</p><div class="experience-list">${[
      ['student','Student','Discover good food for less'],['vendor','Vendor','Turn surplus into something good']
    ].map(([id,title,text]) => `<button type="button" class="experience-card" data-action="choose" data-role="${id}"><span><strong>${title}</strong><small>${text}</small></span>${icon('chevron-right')}</button>`).join('')}</div><p class="auth-link welcome-login">Already have an account? ${action('Log in','shared-login','text')}</p><p class="entry-location">Made for Subang Jaya</p><p class="legal">Good food deserves a second chance.</p></main></div>`;
  }
  function auth(signup=false) {
    const selectedRole = pickedRole === 'vendor' ? 'vendor' : 'student';
    return `<div class="entry-page auth-page"><main class="auth-card"><div class="auth-top"><strong>FoodieNoms</strong>${action('‹ Back','back','text')}</div><div class="auth-art" aria-hidden="true"><span>FRESH FINDS. LESS WASTE.</span><strong>Good food,<br>great possibilities.</strong></div>${pageTitle(signup ? 'Create your account' : 'Welcome back', signup ? 'Join our Subang Jaya food rescue community.' : 'Good food is waiting for you.')}<form data-form="${signup?'signup':'login'}" class="form-stack">${signup ? field('Full name','name','text','','required maxlength="60" autocomplete="name" placeholder="Your full name"') : ''}${signup ? field('Email address','email','email','','required autocomplete="email" placeholder="you@example.com"') : field('Email or username','identifier','text','','required maxlength="254" autocomplete="username" autocapitalize="none" spellcheck="false" placeholder="Email or username"')}${field('Password','password','password','','required minlength="6" autocomplete="'+(signup?'new-password':'current-password')+'" placeholder="Enter your password"')}${signup?`<fieldset class="role-options"><legend>Sign up as</legend>${['student','vendor'].map(r=>`<label><input type="radio" name="role" value="${r}" ${r===selectedRole?'checked':''}><span>Sign up as ${r==='student'?'Student':'Vendor'}</span></label>`).join('')}</fieldset>`:''}<p class="form-error" role="alert" aria-live="polite"></p><button class="button primary" type="submit">${signup?'Create Account':'Log In'}</button></form>${`<p class="auth-link">${signup?'Already have an account?':'New to FoodieNoms?'} ${action(signup?'Log in':'Sign up',signup?'login':'signup','text')}</p>`}</main></div>`;
  }
  const studentNav = [['discover','home','Home'],['nearby','map','Nearby'],['orders','receipt','Orders'],['profile','user','Profile']];
  const vendorNav = [['vendor','home','Dashboard'],['vendor-listings','receipt','Listings'],['vendor-orders','receipt','Orders'],['profile','user','Profile']];
  const adminNav = [['admin','home','Overview'],['admin-vendors','user','Vendors'],['admin-listings','receipt','Listings'],['admin-orders','receipt','Reservations'],['admin-students','user','Students'],['admin-reports','star','Reports'],['admin-activity','bell','Activity']];
  function shell(content, title = '', css = '') {
    const navigation = session.role === 'admin' ? adminNav : session.role === 'vendor' ? vendorNav : studentNav;
    const links = navigation.map(([name,i,label])=>`<button type="button" class="nav-item ${route.name===name?'selected':''}" data-action="nav" data-route="${name}" ${route.name===name?'aria-current="page"':''}>${icon(i)}<span>${label}</span></button>`).join('');
    const isHome = route.name === 'discover';
    return `<div class="app-shell ${session.role==='admin'?'admin-shell':''} ${isHome?'home-shell':''}"><header class="app-header"><button type="button" class="brand" data-action="home">FoodieNoms</button><div class="header-actions">${backStack.length ? action(icon('arrow-left')+' Back','back','text back-link') : ''}<span class="role-chip">${escape(session.role)}</span><button type="button" class="profile-button" data-action="nav" data-route="profile" aria-label="Open profile">${icon('user')}</button></div></header><aside class="side-nav"><p>${session.role==='admin'?'ADMIN CONSOLE':'GOOD FOOD. LESS WASTE.'}</p><nav aria-label="Sidebar">${links}</nav>${action('Log out','logout','text logout-link')}<small>Subang Jaya<br>Good food. Less waste.</small></aside><main class="app-content ${css}" id="main-content">${title ? pageTitle(title) : ''}${content}</main><nav class="bottom-nav" aria-label="Main navigation">${links}</nav></div>`;
  }
  function card(listing) {
    const saved = store.state.favourites.includes(listing.id);
    return `<article class="food-card"><button type="button" class="card-open" data-action="detail" data-id="${listing.id}">${photo(listing)}<span class="card-copy"><small>${escape(vendor(listing.vendorId)?.name)}</small><strong>${escape(listing.name)}</strong><span class="card-price">${money(listing.priceCents)} <del>${money(listing.originalPriceCents)}</del></span><small>Pickup ${pickup(listing)} · ${listing.quantity} left</small></span></button><button type="button" class="save-button ${saved?'saved':''}" data-action="favourite" data-id="${listing.id}" aria-label="${saved?'Remove favourite':'Save favourite'}" aria-pressed="${saved}">${icon('heart')}</button></article>`;
  }
  function matches(listing) { return (category==='All'||listing.category===category) && listing.priceCents<=priceLimit && (listing.name+' '+vendor(listing.vendorId)?.name).toLowerCase().includes(searchText.toLowerCase()); }
  function foodResults(savedOnly=false) {
    const items = store.getAvailable().filter(matches).filter(l=>!savedOnly||store.state.favourites.includes(l.id));
    return items.length ? items.map(card).join('') : blank(savedOnly?'No saved deals yet':'No deals found', savedOnly?'Tap a heart on a food deal to save it here.':'Try another category, search or maximum price.');
  }
  function discover(savedOnly=false) {
    return shell(`${savedOnly?pageTitle('Saved favourites','Your favourite food, ready when you are.'):`<section class="discovery-banner"><h1>Rescue delicious food.</h1><p>Spend less. Waste less. Eat better.</p>${action(icon('map-pin')+' Subang Jaya, Selangor','nav','location-chip','data-route="nearby"')}<label class="search-box">${icon('search')}<input id="food-search" type="search" placeholder="Search meals, bakeries, cafés…" value="${escape(searchText)}" aria-label="Search food or vendor"></label></section><div class="rescue-ribbon">SAVE MORE <span>·</span> RESCUE FOOD <span>·</span> SUBANG JAYA</div><div class="heading-row"><h2>Today’s rescue deals</h2>${action('Filters','filters','text','aria-expanded="false" aria-controls="filters"')}</div>`}<div class="category-tabs" aria-label="Food category">${['All','Bakery','Meals','Pastries','Drinks'].map(c=>action(c,'category',category===c?'category active':'category',`data-category="${c}" aria-pressed="${category===c}"`)).join('')}</div><section class="filter-panel" id="filters" hidden><label class="field"><span>Maximum price: <output id="price-label">${money(priceLimit)}</output></span><input id="price-limit" type="range" min="100" max="3000" step="50" value="${priceLimit}"></label>${action('Clear filters','clear-filters','text')}</section><div class="food-grid" id="food-grid">${foodResults(savedOnly)}</div><p class="quiet-note">Fresh finds. Local favourites. Ready for collection.</p>`,'','discover-content');
  }
  function details() {
    const listing = food(route.data);
    if (!listing || !store.getAvailable().some(l=>l.id===listing.id)) return shell(blank('This deal is no longer available','Explore more food on the Home screen.')+action('Browse food','home'),'Food details');
    return shell(`<div class="detail-layout">${photo(listing,'detail-photo')}<section class="detail-copy">${pageTitle(escape(listing.name))}<div class="detail-price"><strong>${money(listing.priceCents)}</strong><del>${money(listing.originalPriceCents)}</del><span class="saving">Save ${money(listing.originalPriceCents-listing.priceCents)}</span></div><p>${escape(listing.description)}</p><div class="info-panel"><p>${icon('user')}<span>${escape(vendor(listing.vendorId)?.name)}<small>Neighbourhood food partner</small></span></p><p>${icon('receipt')}<span>Pickup today<small>${pickup(listing)}</small></span></p><p>${icon('map-pin')}<span>${escape(vendor(listing.vendorId)?.address)}<small>Collection only</small></span></p></div><p class="availability">${listing.quantity} portions available</p>${action('Reserve for Pickup','checkout','primary','data-id="'+listing.id+'"')}<p class="quiet-note">Pay at pickup · Collect directly from the vendor</p></section></div>`,'','details-content');
  }
  function checkout() {
    const listing = food(route.data);
    if (!listing) return shell(blank('Deal unavailable','Please return to Home.'),'Checkout');
    return shell(`<div class="reading-column">${pageTitle('Confirm reservation','A small rescue. A delicious difference.')}<section class="panel checkout-card">${photo(listing)}<div><h2>${escape(listing.name)}</h2><p>${escape(vendor(listing.vendorId)?.name)}</p><small>Pickup today, ${pickup(listing)}</small></div></section><form data-form="reserve" data-id="${listing.id}" class="form-stack"><label class="field"><span>Quantity (${listing.quantity} available)</span><input type="number" name="quantity" id="reserve-quantity" min="1" max="${listing.quantity}" step="1" value="1" required></label><h2>Payment method</h2><div class="payment-method">${icon('check')}<div><strong>Pay at pickup</strong><p>Pay the vendor when you collect your food.</p></div></div><div class="checkout-total"><span>Total</span><strong id="checkout-total">${money(listing.priceCents)}</strong></div><p class="form-error" role="alert"></p><button type="submit" class="button primary">Confirm Reservation</button></form><p class="quiet-note">Payment is made directly to the vendor at pickup.</p></div>`,'','checkout-content');
  }
  function pass() {
    const reservation = order(route.data);
    if (!reservation) return shell(blank('No pickup pass found','Make a reservation from Home.'),'Pickup pass');
    return shell(`<div class="reading-column pass-page"><div class="success-mark">${icon('check')}</div>${pageTitle(reservation.status==='reserved'?'Reservation confirmed!':'Your pickup pass','Show this code when collecting your food.')}<section class="pickup-pass"><small>YOUR PICKUP PASS</small><h2>${escape(reservation.name)}</h2><p>${escape(reservation.vendorName)}</p><div class="pickup-code">${escape(reservation.code)}</div><p>Today · ${pickup(reservation)}</p><div class="pass-footer"><strong>${escape(reservation.id)}</strong>${status(reservation.status)}</div></section>${action('View My Reservations','nav','primary','data-route="orders"')}${action('Back to Home','home','secondary')}</div>`);
  }
  function orders(vendorMode=false) {
    const orders = store.state.orders.filter(o=>!vendorMode||o.vendorId==='cafe');
    return shell(`${pageTitle(vendorMode?'Incoming reservations':'My reservations', vendorMode?'Check the pickup code before confirming collection.':'Your food rescue journey, all in one place.')}<div class="order-grid">${orders.length?orders.map(o=>`<article class="panel order-card"><div class="heading-row"><strong>${escape(o.id)}</strong>${status(o.status)}</div><h2>${escape(o.name)}</h2><p>${escape(o.vendorName)} · ${o.quantity} portion${o.quantity===1?'':'s'}</p><p>Pickup today, ${pickup(o)}</p><strong class="green">${money(o.totalCents)}</strong>${o.status==='reserved'?vendorMode?`<form data-form="collect" data-id="${o.id}" class="collection-form">${field('Customer pickup code','code','text','','required maxlength="40" autocomplete="off" autocapitalize="characters" placeholder="FN-2026-001"')}<p class="form-error" role="alert"></p><button class="button primary" type="submit">Confirm Pickup</button></form>`:`<div class="order-actions">${action('View pickup pass','pass','primary','data-id="'+o.id+'"')}${action('Cancel reservation','cancel','text','data-id="'+o.id+'"')}</div>`:`<p class="quiet-note">${o.status==='collected'?'Thanks for rescuing good food.':'This reservation has been cancelled.'}</p>`}</article>`).join(''):blank('No reservations yet',vendorMode?'Reservations for Subang Cafe appear here after a student books.':'Reserve a food deal and your pickup pass will appear here.')}</div>`, '');
  }
  function nearby() {
    return shell(`${pageTitle('Deals near you','Find participating food vendors in Subang Jaya.')}<div class="nearby-layout"><section><img class="nearby-map" src="./assets/map.png" alt="Illustrative map of Subang Jaya, not live GPS"><p class="quiet-note">Illustrative map · GPS and directions are not connected.</p></section><div class="food-grid">${store.getAvailable().map(card).join('')}</div></div>`);
  }
  function profile() {
    const savings = store.state.orders.filter(o=>o.status!=='cancelled').reduce((sum,o)=>sum+(o.originalUnitPriceCents-o.unitPriceCents)*o.quantity,0);
    return shell(`<div class="reading-column">${pageTitle('My profile')}<div class="profile-summary"><img src="./assets/avatar.png" alt="Illustrative profile portrait"><div><h2>${escape(store.state.profile.name)}</h2><p>${escape(store.state.profile.email)}</p><small>${escape(session.role)} account</small></div></div>${session.role==='student'?`<div class="impact-card"><span>Your estimated savings</span><strong>${money(savings)}</strong><small>Based on your reservations</small></div>${action(icon('heart')+' Saved favourites','nav','menu-link','data-route="favourites"')}`:''}<form data-form="profile" class="form-stack">${field('Display name','name','text',store.state.profile.name,'required maxlength="60" autocomplete="name"')}${field('Email','email','email',store.state.profile.email,'required autocomplete="email"')}<p class="form-error" role="alert"></p><button class="button primary" type="submit">Save Profile</button></form>${action('Log out','logout','secondary logout-button')}<p class="quiet-note">Your preferences are saved on this device.</p></div>`);
  }
  function vendorDashboard(listOnly=false) {
    const business = vendor('cafe');
    const listings = store.state.listings.filter(l=>l.vendorId==='cafe');
    const pending = store.state.orders.filter(o=>o.vendorId==='cafe'&&o.status==='reserved').length;
    return shell(`${pageTitle(listOnly?'Your listings':'Good afternoon, partner!', 'Subang Cafe · Subang Jaya')}<div class="vendor-overview"><section class="vendor-status"><span>Your business</span><h2>${escape(business.name)}</h2>${status(business.status)}<p>${escape(business.address)}</p></section><div class="metric-grid"><div class="metric"><small>Active listings</small><strong>${listings.filter(l=>l.active).length}</strong></div><div class="metric"><small>Pending pickups</small><strong>${pending}</strong></div></div></div>${business.status!=='approved'?`<div class="information-banner">${icon('bell')}<p>Your business is ${escape(business.status)}. An administrator must approve it before you can publish food deals.</p></div>`:''}<div class="heading-row"><h2>Your surplus food</h2>${action('+ Add Surplus Food','new-listing','primary compact')}</div><div class="listing-grid">${listings.length?listings.map(l=>`<article class="panel listing-card"><div class="listing-top">${photo(l)}<div><h2>${escape(l.name)}</h2><p>${money(l.priceCents)} · ${l.quantity} left</p>${status(l.active?'active':'hidden')}</div></div><div class="listing-actions">${action('Edit listing','edit-listing','secondary','data-id="'+l.id+'"')}${action(l.active?'Hide listing':'Show listing','toggle-listing','text','data-id="'+l.id+'"')}</div></article>`).join(''):blank('Your first rescue starts here','Once approved, add a surplus listing for students to discover.')}</div>`);
  }
  function editor() {
    const listing = route.data ? food(route.data) : null;
    return shell(`<div class="reading-column">${pageTitle(listing?'Edit food listing':'Create surplus listing','Good food deserves a second chance.')}<form data-form="listing" data-id="${listing?.id||''}" class="form-stack">${field('Food name','name','text',listing?.name||'','required maxlength="80" placeholder="Bakery Surprise Bag"')}<label class="field"><span>Description</span><textarea name="description" required maxlength="500" placeholder="What can students look forward to?">${escape(listing?.description||'')}</textarea></label><div class="form-columns">${field('Original price (RM)','original','number',listing?listing.originalPriceCents/100:'','required min="0.01" max="999" step="0.01"')}${field('Rescue price (RM)','price','number',listing?listing.priceCents/100:'','required min="0.01" max="999" step="0.01"')}</div><div class="form-columns">${field('Available quantity','quantity','number',listing?.quantity??4,'required min="0" max="1000" step="1"')}<label class="field"><span>Category</span><select name="category">${['Bakery','Meals','Pastries','Drinks'].map(c=>`<option ${listing?.category===c?'selected':''}>${c}</option>`).join('')}</select></label></div><div class="form-columns">${field('Pickup starts','pickupStart','time',listing?.pickupStart||'17:00','required')}${field('Pickup ends','pickupEnd','time',listing?.pickupEnd||'19:00','required')}</div><p class="form-error" role="alert"></p><button class="button primary" type="submit">${listing?'Save Changes':'Publish Listing'}</button><p class="form-note">Publishing as Subang Cafe. Food artwork is selected by category.</p></form></div>`);
  }
  function admin() {
    const section = route.name;
    let content = '';
    const metrics = [['Student accounts',store.state.students.length],['Approved vendors',store.state.vendors.filter(v=>v.status==='approved').length],['Active listings',store.state.listings.filter(l=>l.active).length],['Reservations',store.state.orders.length]];
    if (section==='admin') content = `${pageTitle('Dashboard overview','Subang Jaya pilot · Local sample data')}<div class="metric-grid admin-metrics">${metrics.map(([label,n])=>`<div class="metric"><small>${label}</small><strong>${n}</strong></div>`).join('')}</div><div class="heading-row"><h2>Recent food listings</h2>${action('View all','nav','text','data-route="admin-listings"')}</div><div class="admin-list">${store.state.listings.map(l=>`<div class="admin-row"><div><strong>${escape(l.name)}</strong><small>${escape(vendor(l.vendorId)?.name)}</small></div>${status(l.active?'active':'hidden')}</div>`).join('')}</div>`;
    if (section==='admin-vendors') content = `${pageTitle('Vendor approvals','Review applications before food is published.')}<div class="admin-list">${store.state.vendors.map(v=>`<article class="panel approval-card"><div class="heading-row"><h2>${escape(v.name)}</h2>${status(v.status)}</div><p>${escape(v.address)}</p>${v.status!=='approved'?`<div class="button-row">${action('Approve','approve','primary compact','data-id="'+v.id+'"')}${action('Reject','reject','secondary compact','data-id="'+v.id+'"')}</div>`:''}</article>`).join('')}</div>`;
    if (section==='admin-listings') content = `${pageTitle('Food listing moderation','Review and manage food offers.')}<div class="admin-list">${store.state.listings.map(l=>`<div class="admin-row"><div><strong>${escape(l.name)}</strong><small>${escape(vendor(l.vendorId)?.name)} · ${l.quantity} available</small></div><div class="row-actions">${status(l.active?'active':'hidden')}${action(l.active?'Hide':'Restore','toggle-listing','secondary compact','data-id="'+l.id+'"')}</div></div>`).join('')}</div>`;
    if (section==='admin-orders') content = `${pageTitle('Reservation oversight','An overview of reservations on this device.')}<div class="admin-list">${store.state.orders.length?store.state.orders.map(o=>`<div class="admin-row"><div><strong>${escape(o.id)} · ${escape(o.name)}</strong><small>${escape(o.vendorName)} · ${o.quantity} portions · ${money(o.totalCents)}</small></div>${status(o.status)}</div>`).join(''):blank('No reservations yet','A student reservation will appear here.')}</div>`;
    if (section==='admin-students') content = `${pageTitle('Student accounts','Accounts on this device.')}<div class="admin-list">${store.state.students.map(p=>`<div class="admin-row"><div><strong>${escape(p.name)}</strong><small>${escape(p.email)}</small></div>${status(p.status||'active')}</div>`).join('')}</div>`;
    if (section==='admin-reports') content = `${pageTitle('Reports & impact','Calculated from reservations on this device.')}<div class="metric-grid admin-metrics">${['reserved','collected','cancelled'].map(s=>`<div class="metric"><small>${s}</small><strong>${store.state.orders.filter(o=>o.status===s).length}</strong></div>`).join('')}<div class="metric"><small>Collected value</small><strong class="money-metric">${money(store.state.orders.filter(o=>o.status==='collected').reduce((s,o)=>s+o.totalCents,0))}</strong></div></div><div class="information-banner"><p>Payments are collected by vendors at pickup.</p></div>`;
    if (section==='admin-activity') content = `${pageTitle('Activity log','Recent activity on this device.')}<div class="admin-list">${store.state.events.length?store.state.events.map(e=>`<div class="admin-row"><div><strong>${escape(e.message)}</strong><small>${new Date(e.createdAt).toLocaleString()}</small></div></div>`).join(''):blank('A fresh start','Approvals, reservations and listing changes will be recorded here.')}</div>`;
    return shell(content);
  }
  function render() {
    if (!session && !['start','login','signup'].includes(route.name)) route = {name:'start',data:null};
    if (session?.role!=='admin' && route.name.startsWith('admin')) route = {name:home(),data:null};
    const screens = {start:intro,login:()=>auth(),signup:()=>auth(true),discover:()=>discover(),favourites:()=>discover(true),detail:details,checkout,pass,orders:()=>orders(),nearby,profile,vendor:()=>vendorDashboard(), 'vendor-listings':()=>vendorDashboard(true),'vendor-orders':()=>orders(true),editor};
    root.innerHTML = route.name.startsWith('admin') ? admin() : (screens[route.name] || intro)();
    document.title = 'FoodieNoms · ' + (route.name==='start'?'Welcome':route.name.replaceAll('-',' '));
    const main = $('#main-content'); if (main) main.scrollTop = 0;
    const selectedNav = root.querySelector('.bottom-nav .selected');
    if (selectedNav) selectedNav.scrollIntoView({block:'nearest',inline:'center'});
  }
  root.addEventListener('click', async event => {
    const button = event.target.closest('[data-action]');
    if (!button) return;
    event.preventDefault();
    const name = button.dataset.action;
    const id = button.dataset.id;
    try {
      if (name==='choose') { pickedRole=button.dataset.role; navigate('login'); }
      else if (name==='back') goBack();
      else if (name==='home') { backStack=[]; navigate(home(),null,true); }
      else if (name==='logout') logout();
      else if (name==='shared-login') { pickedRole=null; navigate('login'); }
      else if (name==='login') navigate('login');
      else if (name==='signup') navigate('signup');
      else if (name==='nav') { backStack=[]; navigate(button.dataset.route,null,true); }
      else if (name==='detail') navigate('detail',id);
      else if (name==='checkout') navigate('checkout',id);
      else if (name==='pass') navigate('pass',id);
      else if (name==='category') { category=button.dataset.category; render(); }
      else if (name==='filters') { const panel=$('#filters'); panel.hidden=!panel.hidden; button.setAttribute('aria-expanded',String(!panel.hidden)); }
      else if (name==='clear-filters') { category='All'; searchText=''; priceLimit=3000; render(); }
      else if (name==='favourite') { const saved=store.toggleFavourite(id); button.classList.toggle('saved',saved); button.setAttribute('aria-pressed',String(saved)); button.setAttribute('aria-label',saved?'Remove favourite':'Save favourite'); if(route.name==='favourites') render(); }
      else if (name==='cancel') {
        const dialog=$('#confirm-dialog');
        $('#confirm-message').textContent='Cancel this reservation? Its portions will become available to other students.';
        dialog.returnValue='';
        dialog.showModal();
        dialog.addEventListener('close', () => {
          if(dialog.returnValue!=='confirm') return;
          try { store.cancelOrder(id); render(); notify('Reservation cancelled. Stock restored.'); } catch(error) { notify(error.message); }
        }, {once:true});
      }
      else if (name==='new-listing') navigate('editor');
      else if (name==='edit-listing') navigate('editor',id);
      else if (name==='toggle-listing') { store.toggleListing(id); render(); }
      else if (name==='approve'||name==='reject') { store.approveVendor(id,name==='approve'); render(); notify('Vendor '+(name==='approve'?'approved.':'rejected.')); }
    } catch(error) { notify(error.message); }
  });
  root.addEventListener('input', event => {
    if(event.target.id==='food-search') { searchText=event.target.value; $('#food-grid').innerHTML=foodResults(route.name==='favourites'); }
    if(event.target.id==='price-limit') { priceLimit=Number(event.target.value); $('#price-label').textContent=money(priceLimit); $('#food-grid').innerHTML=foodResults(route.name==='favourites'); }
    if(event.target.id==='reserve-quantity') { const listing=food(route.data); const n=Number(event.target.value); $('#checkout-total').textContent=Number.isInteger(n)&&n>0?money(listing.priceCents*n):'—'; }
  });
  root.addEventListener('submit', event => {
    event.preventDefault();
    const form=event.target;
    const values=new FormData(form);
    const errorElement=form.querySelector('.form-error');
    if(errorElement) errorElement.textContent='';
    try {
      if(form.dataset.form==='login') {
        const identifier=String(values.get('identifier')||'').trim();
        if(identifier.toLowerCase()==='admin123') {
          if(identifier!=='admin123'||values.get('password')!=='admin@123') throw Error('Incorrect username or password.');
          login('admin');
        } else {
          if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifier)) throw Error('Enter a valid email address or username.');
          const role=store.resolveRole(identifier) || pickedRole || 'student';
          store.rememberRole(identifier,role);
          login(role);
          notify('Welcome back. Your next great find is waiting.');
        }
      }
      if(form.dataset.form==='signup') {
        const role=values.get('role');
        if(!['student','vendor'].includes(role)) throw Error('Choose Student or Vendor.');
        store.saveProfile(String(values.get('name')),String(values.get('email')));
        store.rememberRole(String(values.get('email')),role);
        login(role);
        notify('Your profile is ready. Welcome to FoodieNoms.');
      }
      if(form.dataset.form==='reserve') {
        const reservation=store.reserve(form.dataset.id,Number(values.get('quantity')));
        navigate('pass',reservation.id,true);
      }
      if(form.dataset.form==='collect') {
        store.collectOrder(form.dataset.id,String(values.get('code')).trim());
        render(); notify('Pickup confirmed. Thank you for rescuing food.');
      }
      if(form.dataset.form==='profile') {
        store.saveProfile(String(values.get('name')),String(values.get('email')));
        render(); notify('Profile saved.');
      }
      if(form.dataset.form==='listing') {
        const originalPriceCents=Math.round(Number(values.get('original'))*100);
        const priceCents=Math.round(Number(values.get('price'))*100);
        if(priceCents>=originalPriceCents) throw Error('Rescue price must be lower than the original price.');
        const category=String(values.get('category'));
        const fields={vendorId:'cafe',name:String(values.get('name')),description:String(values.get('description')),category,
          originalPriceCents,priceCents,quantity:Number(values.get('quantity')),
          pickupStart:String(values.get('pickupStart')),pickupEnd:String(values.get('pickupEnd')),
          image:category==='Meals'?'lunch':category==='Pastries'?'pastry':'bakery',active:true};
        store.saveListing(fields,form.dataset.id||undefined);
        backStack=[];navigate('vendor-listings',null,true);notify('Listing published. Students can now discover it.');
      }
    } catch(error) { if(errorElement) { errorElement.textContent=error.message; errorElement.scrollIntoView({block:'nearest',behavior:'smooth'}); } else notify(error.message); }
  });
  // Keep Live Server edits uncached. Hosted HTTPS deployments can work offline.
  if('serviceWorker' in navigator && window.isSecureContext && !['localhost','127.0.0.1','[::1]'].includes(location.hostname)) {
    navigator.serviceWorker.register('./sw.js').catch(() => { /* Online demo remains usable when installation is unavailable. */ });
  }
  if (new URLSearchParams(location.search).get('admin') === '1') {
    pickedRole = null; route = {name:'login',data:null};
  }
  render();
})();

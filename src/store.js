(() => {
const seed = () => ({vendors:[{id:'bakery',name:'Sample Bakery',status:'approved',address:'SS15, Subang Jaya'},{id:'cafe',name:'Subang Cafe',status:'pending',address:'SS15, Subang Jaya'}],listings:[{id:'bag',vendorId:'bakery',title:'Bakery Surprise Bag',description:'A little surprise, a lot to love. A selection of freshly baked croissants, breads and pastries from today’s bake.',category:'Bakery',price:8,original:20,quantity:4,pickup:'5–7 PM',image:'🥐',status:'active'},{id:'lunch',vendorId:'bakery',title:'Cafe Lunch Box',description:'A comforting, freshly prepared lunch with rice, vegetables and a delicious daily main.',category:'Meals',price:9.9,original:18,quantity:3,pickup:'4–6 PM',image:'🍱',status:'active'},{id:'pastry',vendorId:'bakery',title:'Pastry Selection',description:'Sweet little moments. Enjoy an assortment of today’s handmade pastries.',category:'Pastries',price:6.5,original:15,quantity:5,pickup:'6–8 PM',image:'🧁',status:'active'}],orders:[],favourites:[],logs:[],profile:{name:'Student Account',email:'student@example.com'}});
function reserve(state,id,quantity){
 const item=state.listings.find(x=>x.id===id);
 const vendor=state.vendors.find(x=>x.id===item?.vendorId);
 if(!item || vendor?.status!=='approved' || item.status!=='active' || !Number.isInteger(quantity) || quantity<1 || item.quantity<quantity) throw Error('This quantity is no longer available. Please choose another deal.');
 const order={id:'FN-'+String(state.orders.length+1).padStart(3,'0'),listingId:id,title:item.title,vendorId:item.vendorId,quantity,total:Math.round(item.price*quantity*100)/100,pickup:item.pickup,status:'Reserved',code:String(100000+Math.floor(Math.random()*900000))};
 item.quantity-=quantity; state.orders.unshift(order); state.logs.unshift('Reservation '+order.id+' created'); return order;
}
function cancel(state,id){const o=state.orders.find(x=>x.id===id);if(!o||o.status!=='Reserved')throw Error('Only reserved orders can be cancelled.');o.status='Cancelled';const item=state.listings.find(x=>x.id===o.listingId);if(item)item.quantity+=o.quantity;state.logs.unshift(o.id+' cancelled');}
function collect(state,id,code){const o=state.orders.find(x=>x.id===id);if(!o||o.status!=='Reserved')throw Error('This order is not awaiting collection.');if(o.code!==code)throw Error('Pickup code does not match.');o.status='Collected';state.logs.unshift(o.id+' collected');}

globalThis.FoodieStore = {seed, reserve, cancel, collect};
})();

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../demo_store.dart';
import '../ui.dart';

void openFood(BuildContext context,DemoStore store,FoodListing food)=>
  Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>FoodDetail(store:store,food:food)));

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key,required this.store});
  final DemoStore store;
  @override
  State<DiscoverScreen> createState()=>_DiscoverScreenState();
}
class _DiscoverScreenState extends State<DiscoverScreen> {
  String search='',category='All';bool favourites=false;double maximum=30;
  @override
  Widget build(BuildContext context){
    final items=widget.store.available.where((l)=>(category=='All'||l.category==category)&&
      l.price<=maximum&&(!favourites||widget.store.favourites.contains(l.id))&&
      '${l.title} ${widget.store.vendor(l.vendorId).name}'.toLowerCase().contains(search.toLowerCase())).toList();
    return PageList(children:[
      Container(padding:const EdgeInsets.all(23),margin:const EdgeInsets.only(bottom:22),
        decoration:BoxDecoration(color:darkGreen,borderRadius:BorderRadius.circular(18)),
        child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('GOOD FOOD. LESS WASTE.',style:TextStyle(color:Color(0xFFD4EDAB),fontSize:10,letterSpacing:1.5)),
          SizedBox(height:12),Text('Rescue delicious food.',style:TextStyle(color:Colors.white,fontSize:29,fontWeight:FontWeight.w800)),
          SizedBox(height:8),Text('Spend less. Waste less. Eat better.',style:TextStyle(color:Color(0xFFD4E3D4))),
          SizedBox(height:20),Row(children:[Icon(Icons.location_on_outlined,color:Colors.white,size:16),SizedBox(width:6),
            Text('Subang Jaya, Selangor',style:TextStyle(color:Colors.white,fontSize:12))]),
        ])),
      TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(
        hintText:'Search meals, bakeries, cafés…',prefixIcon:Icon(Icons.search),labelText:'Find a deal')),
      const SizedBox(height:15),Wrap(spacing:8,runSpacing:4,children:[
        for(final c in ['All','Bakery','Meals','Pastries','Drinks']) ChoiceChip(label:Text(c),selected:category==c,onSelected:(_)=>setState(()=>category=c)),
      ]),
      Row(children:[Expanded(child:Text('Maximum ${money(maximum)}',style:const TextStyle(fontSize:12))),
        FilterChip(label:const Text('Saved'),avatar:const Icon(Icons.favorite_border,size:17),selected:favourites,
          onSelected:(v)=>setState(()=>favourites=v))]),
      Slider(value:maximum,min:1,max:30,divisions:29,label:money(maximum),onChanged:(v)=>setState(()=>maximum=v)),
      const SectionTitle('Today’s rescue deals',eyebrow:'FRESH TODAY. GONE SOON.'),
      if(items.isEmpty)const EmptyContent('No deals found','Try another category, a higher maximum price or a different search.'),
      for(final food in items)FoodCard(store:widget.store,food:food,onTap:()=>openFood(context,widget.store,food)),
      const SizedBox(height:14),const DemoNotice('Sample food listings and artwork. Collection only. Payments are simulated.'),
    ]);
  }
}

class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key,required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context)=>PageList(children:[
    const SectionTitle('Deals near you',subtitle:'Discover our Subang Jaya food rescue community.'),
    const DemoMap(),const DemoNotice('Illustrative map only. GPS, distances and directions are not connected in this demo.'),
    for(final food in store.available)FoodCard(store:store,food:food,onTap:()=>openFood(context,store,food)),
  ]);
}

class FoodDetail extends StatefulWidget {
  const FoodDetail({super.key,required this.store,required this.food});
  final DemoStore store;
  final FoodListing food;
  @override
  State<FoodDetail> createState()=>_FoodDetailState();
}
class _FoodDetailState extends State<FoodDetail> {
  int quantity=1;
  @override
  Widget build(BuildContext context)=>ScreenFrame(store:widget.store,title:'Food details',builder:(c){
    final l=widget.food;
    return PageList(width:650,children:[
      Container(height:220,alignment:Alignment.center,margin:const EdgeInsets.only(bottom:25),
        decoration:BoxDecoration(color:const Color(0xFFEEE1CB),borderRadius:BorderRadius.circular(18)),
        child:Text(l.emoji,style:const TextStyle(fontSize:120))),
      SectionTitle(l.title,subtitle:'${widget.store.vendor(l.vendorId).name} · ★ 4.5 sample rating'),
      Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
        Text(money(l.price),style:const TextStyle(color:forest,fontSize:26,fontWeight:FontWeight.w800)),
        Text(money(l.original),style:const TextStyle(decoration:TextDecoration.lineThrough,color:Colors.black45)),
        StatusBadge('Save ${money(l.original-l.price)}')]),
      const SizedBox(height:18),Text(l.description,style:const TextStyle(height:1.6)),const SizedBox(height:20),
      InfoCard(color:mint,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('◷ Pickup today, ${l.pickup}'),const SizedBox(height:12),
        Text('⌖ ${widget.store.vendor(l.vendorId).address}'),const SizedBox(height:12),Text('${l.quantity} portions available')])),
      Row(children:[const Expanded(child:Text('Quantity')),IconButton(tooltip:'Reduce quantity',onPressed:quantity>1?()=>setState(()=>quantity--):null,icon:const Icon(Icons.remove)),
        Text('$quantity',style:const TextStyle(fontWeight:FontWeight.w800)),IconButton(tooltip:'Increase quantity',onPressed:quantity<l.quantity?()=>setState(()=>quantity++):null,icon:const Icon(Icons.add))]),
      const SizedBox(height:18),FilledButton(onPressed:l.quantity>=quantity&&widget.store.available.contains(l)?()=>Navigator.push(context,
        MaterialPageRoute<void>(builder:(_)=>CheckoutScreen(store:widget.store,food:l,quantity:quantity))):null,
        child:Text('Reserve for Pickup · ${money(l.price*quantity)}')),
      const SizedBox(height:12),const Text('Pay at pickup · Demo only',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Colors.black54)),
    ]);
  });
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key,required this.store,required this.food,required this.quantity});
  final DemoStore store;
  final FoodListing food;
  final int quantity;
  @override
  Widget build(BuildContext context)=>ScreenFrame(store:store,title:'Checkout',builder:(c)=>PageList(width:600,children:[
    const SectionTitle('Confirm reservation',subtitle:'Your next delicious rescue is almost yours.'),
    InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(food.title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)),const SizedBox(height:12),
      Text('Quantity: $quantity'),const SizedBox(height:8),Text('Pickup today, ${food.pickup}')])),
    const SizedBox(height:15),const Text('Payment method',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:15),
    const InfoCard(color:mint,child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.payments_outlined,color:forest),
      title:Text('Pay at pickup'),subtitle:Text('Simulated checkout. No online payment.'))),
    Padding(padding:const EdgeInsets.symmetric(vertical:25),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,
      children:[const Text('Total',style:TextStyle(fontSize:20)),Text(money(food.price*quantity),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:forest))])),
    FilledButton(onPressed:(){
      try{final order=store.reserve(food.id,quantity);Navigator.pushReplacement(context,
        MaterialPageRoute<void>(builder:(_)=>PickupPass(store:store,order:order)));}
      catch(error){showError(context,error);}
    },child:const Text('Confirm Reservation')),
    const SizedBox(height:20),const DemoNotice('This reserves sample stock in this app session only. No messages or payment requests are sent.'),
  ]));
}

class PickupPass extends StatelessWidget {
  const PickupPass({super.key,required this.store,required this.order});
  final DemoStore store;
  final Reservation order;
  @override
  Widget build(BuildContext context)=>ScreenFrame(store:store,title:'Pickup pass',builder:(c)=>PageList(width:600,children:[
    const Icon(Icons.check_circle_outline,size:70,color:forest),const SizedBox(height:18),
    SectionTitle(order.status=='Reserved'?'Reservation confirmed!':'Your pickup pass',subtitle:'Show this code when collecting your food.'),
    InfoCard(child:Column(children:[Text(order.title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
      const SizedBox(height:14),Text(store.vendor(order.vendorId).name),const SizedBox(height:12),Text('Pickup today, ${order.pickup}'),
      Container(width:double.infinity,alignment:Alignment.center,margin:const EdgeInsets.symmetric(vertical:25),padding:const EdgeInsets.all(22),
        decoration:BoxDecoration(color:mint,borderRadius:BorderRadius.circular(14)),
        child:SelectableText(order.code,style:const TextStyle(fontSize:38,letterSpacing:6,fontWeight:FontWeight.w800,color:forest))),
      Text(order.id,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:14),StatusBadge(order.status),
      TextButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:order.code));if(c.mounted){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Pickup code copied.')));}},
        icon:const Icon(Icons.copy,size:17),label:const Text('Copy pickup code'))])),
    FilledButton(onPressed:()=>Navigator.popUntil(context,(r)=>r.isFirst),child:const Text('Back to Home')),
    const SizedBox(height:18),const DemoNotice('Numeric demo pickup code. QR scanning and production verification are not connected.'),
  ]));
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key,required this.store,this.vendorMode=false});
  final DemoStore store;
  final bool vendorMode;
  @override
  Widget build(BuildContext context)=>PageList(children:[
    SectionTitle(vendorMode?'Incoming reservations':'My reservations',subtitle:vendorMode?'Verify the customer’s pickup code before collection.':'Your next delicious rescue is waiting.'),
    if(store.reservations.isEmpty)EmptyContent('No reservations yet',vendorMode?'Student demo reservations appear here.':'Browse a deal and reserve your first rescue.'),
    for(final order in store.reservations)InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[Text(order.id,style:const TextStyle(fontWeight:FontWeight.w700)),StatusBadge(order.status)]),
      const SizedBox(height:15),Text(order.title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)),
      const SizedBox(height:9),Text('${order.quantity} portions · ${money(order.total)}'),const SizedBox(height:8),
      Text('${store.vendor(order.vendorId).name} · ${order.pickup}',style:const TextStyle(color:Colors.black54,fontSize:12)),
      if(order.status=='Reserved')...[
        const SizedBox(height:18),
        if(vendorMode)FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CollectionScreen(store:store,order:order))),
          icon:const Icon(Icons.pin_outlined),label:const Text('Verify collection'))
        else Wrap(spacing:10,runSpacing:8,children:[FilledButton(onPressed:()=>Navigator.push(context,
          MaterialPageRoute<void>(builder:(_)=>PickupPass(store:store,order:order))),child:const Text('View pickup pass')),
          TextButton(onPressed:()async{if(await confirm(context,'Cancel this reservation and return its food to available stock?')){
            try{store.cancel(order);}catch(error){if(context.mounted)showError(context,error);}
          }},child:const Text('Cancel reservation'))]),
      ]else Padding(padding:const EdgeInsets.only(top:14),child:Text(order.status=='Collected'?'Thanks for rescuing good food!':'Stock returned to available deals.',style:const TextStyle(fontSize:12,color:forest))),
    ])),
  ]);
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key,required this.store,required this.order});
  final DemoStore store;final Reservation order;
  @override
  State<CollectionScreen> createState()=>_CollectionScreenState();
}
class _CollectionScreenState extends State<CollectionScreen> {
  final code=TextEditingController();String? error;
  @override
  void dispose(){code.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>ScreenFrame(store:widget.store,title:'Verify collection',builder:(c)=>PageList(width:600,children:[
    SectionTitle('Ready for pickup?',subtitle:'${widget.order.id} · ${widget.order.title}'),
    const DemoNotice('Ask the student to show their six-digit pickup code. It can only be collected once.'),
    TextField(controller:code,keyboardType:TextInputType.number,maxLength:6,inputFormatters:[FilteringTextInputFormatter.digitsOnly],
      decoration:InputDecoration(labelText:'Pickup code',errorText:error)),const SizedBox(height:20),
    FilledButton(onPressed:(){try{widget.store.collect(widget.order,code.text);Navigator.pop(context);}
      catch(e){setState(()=>error=e is StateError?e.message:e.toString());}},child:const Text('Confirm Pickup')),
  ]));
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key,required this.store,this.vendorMode=false});
  final DemoStore store;final bool vendorMode;
  @override
  State<ProfileScreen> createState()=>_ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
  late final name=TextEditingController(text:widget.store.studentName);
  late final email=TextEditingController(text:widget.store.studentEmail);
  @override
  void dispose(){name.dispose();email.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>PageList(width:600,children:[
    SectionTitle(widget.vendorMode?'Business profile':'My profile',subtitle:widget.vendorMode?'Sample Bakery and Subang Cafe · Subang Jaya':'Your small choices make a difference.'),
    if(widget.vendorMode)InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Subang Cafe',style:TextStyle(fontWeight:FontWeight.w700,fontSize:20)),const SizedBox(height:10),
      const Text('SS15, Subang Jaya'),const SizedBox(height:12),StatusBadge(widget.store.vendor('cafe').status)]))
    else ...[
      InfoCard(color:mint,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Estimated savings'),
        const SizedBox(height:12),Text(money(widget.store.reservations.where((o)=>o.status!='Cancelled').fold<double>(0,(s,o)=>s+o.saving)),
          style:const TextStyle(fontSize:30,fontWeight:FontWeight.w800,color:forest)),const SizedBox(height:9),
        const Text('Based on sample reservations.',style:TextStyle(fontSize:11))])),
      TextField(controller:name,decoration:const InputDecoration(labelText:'Display name')),const SizedBox(height:18),
      TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email')),const SizedBox(height:22),
      FilledButton(onPressed:(){try{widget.store.saveProfile(name.text,email.text);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Demo profile saved.')));}
        catch(error){showError(context,error);}},child:const Text('Save profile')),
    ],
    const SizedBox(height:20),const DemoNotice('Demonstration profile only. No real account is created. Use the top-right menu to switch experience or reset the demo.'),
  ]);
}

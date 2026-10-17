import 'package:flutter/material.dart';
import '../demo_store.dart';
import '../ui.dart';

void editListing(BuildContext context,DemoStore store,[FoodListing? listing])=>
  Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ListingEditor(store:store,listing:listing)));

class VendorDashboard extends StatelessWidget {
  const VendorDashboard({super.key,required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context)=>PageList(children:[
    Container(padding:const EdgeInsets.all(24),margin:const EdgeInsets.only(bottom:22),
      decoration:BoxDecoration(color:darkGreen,borderRadius:BorderRadius.circular(18)),
      child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('YOUR FOOD BUSINESS, WITH PURPOSE',style:TextStyle(color:Color(0xFFD4EDAB),fontSize:10,letterSpacing:1.2)),
        SizedBox(height:15),Text('Good afternoon, partner!',style:TextStyle(fontSize:27,color:Colors.white,fontWeight:FontWeight.w800)),
        SizedBox(height:10),Text('Let’s give good food another chance.',style:TextStyle(color:Color(0xFFD4E3D4))),
      ])),
    InfoCard(color:mint,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Active listings: ${store.listings.where((l)=>l.status=='active').length}',style:const TextStyle(fontWeight:FontWeight.w700)),
      const SizedBox(height:12),Text('Pending pickups: ${store.reservations.where((o)=>o.status=='Reserved').length}'),
      const SizedBox(height:12),Text('Collected value: ${money(store.reservations.where((o)=>o.status=='Collected').fold<double>(0,(sum,o)=>sum+o.total))}'),
    ])),
    if(store.vendor('cafe').status!='approved')DemoNotice('Subang Cafe is ${store.vendor('cafe').status}. Switch to Administrator → Vendors to approve it before publishing. Sample Bakery is already approved.'),
    FilledButton.icon(onPressed:()=>editListing(context,store),icon:const Icon(Icons.add),label:const Text('Add Surplus Food')),
    const SizedBox(height:28),const SectionTitle('Your listings',subtitle:'Sample Bakery and Subang Cafe'),
    ...listingRows(context,store),
  ]);
}

List<Widget> listingRows(BuildContext context,DemoStore store)=>[
  for(final food in store.listings)InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(food.emoji,style:const TextStyle(fontSize:36)),const SizedBox(width:14),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(food.title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),
        const SizedBox(height:8),Text('${money(food.price)} · ${food.quantity} left',style:const TextStyle(color:forest,fontWeight:FontWeight.w600)),
        const SizedBox(height:7),Text(store.vendor(food.vendorId).name,style:const TextStyle(fontSize:11,color:Colors.black54))]))]),
    const SizedBox(height:14),Row(children:[StatusBadge(food.status),const Spacer(),
      TextButton(onPressed:()=>editListing(context,store,food),child:const Text('Edit listing'))]),
  ])),
];

class VendorListings extends StatelessWidget {
  const VendorListings({super.key,required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context)=>PageList(children:[
    const SectionTitle('Manage listings',subtitle:'Keep your surplus deals fresh and up to date.'),
    FilledButton.icon(onPressed:()=>editListing(context,store),icon:const Icon(Icons.add),label:const Text('Create a listing')),
    const SizedBox(height:22),...listingRows(context,store),
  ]);
}

class ListingEditor extends StatefulWidget {
  const ListingEditor({super.key,required this.store,this.listing});
  final DemoStore store;final FoodListing? listing;
  @override
  State<ListingEditor> createState()=>_ListingEditorState();
}
class _ListingEditorState extends State<ListingEditor> {
  final form=GlobalKey<FormState>();
  late final title=TextEditingController(text:widget.listing?.title??'');
  late final description=TextEditingController(text:widget.listing?.description??'');
  late final price=TextEditingController(text:widget.listing?.price.toStringAsFixed(2)??'');
  late final original=TextEditingController(text:widget.listing?.original.toStringAsFixed(2)??'');
  late final quantity=TextEditingController(text:'${widget.listing?.quantity??4}');
  late String category=widget.listing?.category??'Bakery',pickup=widget.listing?.pickup??'5–7 PM';
  String? error;
  @override
  void dispose(){for(final c in [title,description,price,original,quantity]){c.dispose();}super.dispose();}
  String? requiredValue(String? s)=>s==null||s.trim().isEmpty?'This field is required.':null;
  String? validPrice(String? s){final n=double.tryParse(s??'');return n==null||!n.isFinite||n<=0||n>999?'Enter a price from 0.01 to 999.':null;}
  @override
  Widget build(BuildContext context)=>ScreenFrame(store:widget.store,title:widget.listing==null?'Create surplus listing':'Edit listing',builder:(c)=>PageList(width:650,children:[
    const SectionTitle('Good food deserves a home.',subtitle:'Share a delicious deal with students nearby.'),
    Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      TextFormField(controller:title,maxLength:80,validator:requiredValue,decoration:const InputDecoration(labelText:'Food name')),
      const SizedBox(height:16),TextFormField(controller:description,maxLength:500,maxLines:3,validator:requiredValue,decoration:const InputDecoration(labelText:'Description')),
      const SizedBox(height:16),TextFormField(controller:original,keyboardType:const TextInputType.numberWithOptions(decimal:true),validator:validPrice,
        decoration:const InputDecoration(labelText:'Original price (RM)')),
      const SizedBox(height:16),TextFormField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),validator:validPrice,
        decoration:const InputDecoration(labelText:'Rescue price (RM)')),
      const SizedBox(height:16),TextFormField(controller:quantity,keyboardType:TextInputType.number,
        validator:(s){final n=int.tryParse(s??'');return n==null||n<0||n>1000?'Enter a whole number from 0 to 1000.':null;},
        decoration:const InputDecoration(labelText:'Available quantity')),
      const SizedBox(height:16),DropdownButtonFormField<String>(initialValue:category,decoration:const InputDecoration(labelText:'Food category'),
        items:[for(final v in ['Bakery','Meals','Pastries','Drinks'])DropdownMenuItem(value:v,child:Text(v))],onChanged:(v)=>setState(()=>category=v!)),
      const SizedBox(height:16),DropdownButtonFormField<String>(initialValue:pickup,decoration:const InputDecoration(labelText:'Pickup window'),
        items:[for(final v in ['4–6 PM','5–7 PM','6–8 PM'])DropdownMenuItem(value:v,child:Text(v))],onChanged:(v)=>setState(()=>pickup=v!)),
      const SizedBox(height:22),DemoNotice(widget.listing==null?'Publishing as Subang Cafe. Administrator approval is required.':'Editing a sample vendor listing. Food artwork is illustrative.'),
      if(error!=null)Padding(padding:const EdgeInsets.only(bottom:16),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      FilledButton(onPressed:(){if(!form.currentState!.validate())return;
        try{widget.store.saveListing(id:widget.listing?.id,title:title.text,description:description.text,
          category:category,price:double.parse(price.text),original:double.parse(original.text),quantity:int.parse(quantity.text),pickup:pickup);
          Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Listing saved. View it in the Student experience.')));}
        catch(e){setState(()=>error=e is StateError?e.message:e.toString());}
      },child:Text(widget.listing==null?'Publish Listing':'Save Changes')),
    ])),
  ]));
}

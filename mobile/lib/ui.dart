import 'package:flutter/material.dart';
import 'demo_store.dart';

const forest = Color(0xFF236541);
const darkGreen = Color(0xFF164E3B);
const cream = Color(0xFFFCFAF5);
const mint = Color(0xFFE4F1E5);
const ink = Color(0xFF223B2F);

void showError(BuildContext context, Object error) {
  final message = error is StateError ? error.message : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(BuildContext context, String message) async =>
  await showDialog<bool>(context:context, builder:(c)=>AlertDialog(
    title:const Text('Please confirm'), content:Text(message), actions:[
      TextButton(onPressed:()=>Navigator.pop(c,false), child:const Text('Keep it')),
      FilledButton(onPressed:()=>Navigator.pop(c,true), child:const Text('Confirm')),
    ])) ?? false;

class PageList extends StatelessWidget {
  const PageList({super.key, required this.children, this.width=900});
  final List<Widget> children;
  final double width;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding:const EdgeInsets.all(20), child:Center(child:ConstrainedBox(
      constraints:BoxConstraints(maxWidth:width), child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch, children:children))));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title,{super.key,this.subtitle,this.eyebrow});
  final String title;
  final String? subtitle,eyebrow;
  @override
  Widget build(BuildContext context) => Padding(padding:const EdgeInsets.only(bottom:22),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(eyebrow!=null) Padding(padding:const EdgeInsets.only(bottom:10),child:Text(
        eyebrow!,style:const TextStyle(color:forest,fontSize:10,fontWeight:FontWeight.w700,letterSpacing:1.5))),
      Text(title,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800,letterSpacing:-.7)),
      if(subtitle!=null) Padding(padding:const EdgeInsets.only(top:9),child:Text(subtitle!,style:const TextStyle(color:Colors.black54,height:1.5))),
    ]));
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key,required this.child,this.color=Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:14),
    padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:color,
      borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE0E6DB))),child:child);
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status,{super.key});
  final String status;
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
    decoration:BoxDecoration(color:['Cancelled','hidden','rejected'].contains(status)?const Color(0xFFECE8E0):mint,
      borderRadius:BorderRadius.circular(24)),child:Text(status,style:const TextStyle(color:forest,fontSize:11,fontWeight:FontWeight.w700)));
}

class DemoNotice extends StatelessWidget {
  const DemoNotice(this.message,{super.key});
  final String message;
  @override
  Widget build(BuildContext context)=>InfoCard(color:const Color(0xFFEEF2E2),child:Row(
    crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.info_outline,size:19,color:forest),
      const SizedBox(width:10),Expanded(child:Text(message,style:const TextStyle(fontSize:12,height:1.5)))]));
}

class EmptyContent extends StatelessWidget {
  const EmptyContent(this.title,this.message,{super.key});
  final String title,message;
  @override
  Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:40,horizontal:10),
    child:Column(children:[const Icon(Icons.eco_outlined,size:55,color:forest),const SizedBox(height:15),
      Text(title,style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),
      const SizedBox(height:10),Text(message,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54,height:1.5))]));
}

class FoodCard extends StatelessWidget {
  const FoodCard({super.key,required this.store,required this.food,required this.onTap});
  final DemoStore store;
  final FoodListing food;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context)=>Card(margin:const EdgeInsets.only(bottom:14),
    clipBehavior:Clip.antiAlias,child:InkWell(onTap:onTap,child:Padding(
      padding:const EdgeInsets.all(12),child:Row(children:[Container(width:78,height:92,
        decoration:BoxDecoration(color:food.category=='Meals'?mint:const Color(0xFFF0E2CE),borderRadius:BorderRadius.circular(12)),
        alignment:Alignment.center,child:Text(food.emoji,style:const TextStyle(fontSize:43))),const SizedBox(width:13),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(store.vendor(food.vendorId).name,style:const TextStyle(color:Colors.black54,fontSize:11)),
        const SizedBox(height:6),Text(food.title,style:const TextStyle(fontWeight:FontWeight.w700)),
        const SizedBox(height:6),Text('Pickup ${food.pickup} · ${food.quantity} left',style:const TextStyle(fontSize:11,color:Colors.black54)),
        const SizedBox(height:7),Wrap(spacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
          Text(money(food.price),style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:forest)),
          Text(money(food.original),style:const TextStyle(decoration:TextDecoration.lineThrough,color:Colors.black45,fontSize:11))])])),
      IconButton(tooltip:store.favourites.contains(food.id)?'Remove favourite':'Save favourite',
        onPressed:()=>store.toggleFavourite(food.id),icon:Icon(store.favourites.contains(food.id)?Icons.favorite:Icons.favorite_border,color:forest)),
    ])))) ;
}

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key,required this.store,required this.title,required this.builder});
  final DemoStore store;
  final String title;
  final Widget Function(BuildContext) builder;
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(title)),
    body:SafeArea(child:AnimatedBuilder(animation:store,builder:(c,_)=>builder(c))));
}

class DemoMap extends StatelessWidget {
  const DemoMap({super.key});
  @override
  Widget build(BuildContext context)=>Semantics(label:'Illustrative Subang Jaya map. Not live GPS.',
    child:Container(height:240,margin:const EdgeInsets.only(bottom:16),clipBehavior:Clip.antiAlias,
      decoration:BoxDecoration(color:const Color(0xFFD8EBD9),borderRadius:BorderRadius.circular(16)),
      child:LayoutBuilder(builder:(c,b)=>Stack(children:[
        for(var i=1;i<5;i++) Positioned(left:b.maxWidth*i/5,top:0,bottom:0,child:Container(width:9,color:cream)),
        for(var i=1;i<4;i++) Positioned(left:0,right:0,top:240*i/4,child:Container(height:9,color:cream)),
        Positioned(left:25,top:20,child:Container(width:75,height:60,decoration:BoxDecoration(color:const Color(0xFFB1D39F),borderRadius:BorderRadius.circular(17)))),
        const Center(child:Text('SUBANG JAYA',style:TextStyle(color:forest,fontWeight:FontWeight.w800))),
        const Positioned(left:55,top:65,child:Icon(Icons.location_on,color:forest,size:35)),
        const Positioned(right:50,top:35,child:Icon(Icons.location_on,color:forest,size:35)),
        const Positioned(right:90,bottom:28,child:Icon(Icons.location_on,color:forest,size:35)),
      ]))));
}

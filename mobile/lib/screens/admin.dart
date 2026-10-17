import 'package:flutter/material.dart';
import '../demo_store.dart';
import '../ui.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key,required this.store});
  final DemoStore store;
  @override
  State<AdminScreen> createState()=>_AdminScreenState();
}
class _AdminScreenState extends State<AdminScreen> {
  static const tabs=['Overview','Students','Vendors','Listings','Reservations','Reports','Activity Log','Settings'];
  int index=0;
  DemoStore get store=>widget.store;
  Widget metrics()=>Wrap(spacing:12,runSpacing:4,children:[
    for(final pair in <(String,int)>[
      ('Students',1),('Approved vendors',store.vendors.where((v)=>v.status=='approved').length),
      ('Active listings',store.listings.where((l)=>l.status=='active').length),('Reservations',store.reservations.length),
    ])SizedBox(width:150,child:InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(pair.$1,style:const TextStyle(fontSize:11,color:Colors.black54)),const SizedBox(height:15),
      Text('${pair.$2}',style:const TextStyle(color:forest,fontSize:28,fontWeight:FontWeight.w800))]))),
  ]);
  List<Widget> listingRows()=>[
    for(final food in store.listings)InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(food.title,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:9),
      Text('${store.vendor(food.vendorId).name} · ${food.quantity} available',style:const TextStyle(fontSize:12,color:Colors.black54)),
      const SizedBox(height:12),Row(children:[StatusBadge(food.status),const Spacer(),
        TextButton(onPressed:()=>store.moderate(food),child:Text(food.status=='active'?'Hide listing':'Restore'))]),
    ])),
  ];
  @override
  Widget build(BuildContext context)=>LayoutBuilder(builder:(c,b){
    final wide=b.maxWidth>850;
    return Row(children:[
      if(wide)Container(width:200,color:darkGreen,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Padding(padding:EdgeInsets.all(22),child:Text('ADMIN CONSOLE',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800))),
        for(var i=0;i<tabs.length;i++)ListTile(selected:index==i,selectedTileColor:forest,
          title:Text(tabs[i],style:const TextStyle(color:Colors.white,fontSize:13)),onTap:()=>setState(()=>index=i)),
      ])),
      Expanded(child:PageList(children:[
        if(!wide)Padding(padding:const EdgeInsets.only(bottom:22),child:DropdownButtonFormField<int>(
          key:ValueKey(index),initialValue:index,decoration:const InputDecoration(labelText:'Admin section'),
          items:[for(var i=0;i<tabs.length;i++)DropdownMenuItem(value:i,child:Text(tabs[i]))],onChanged:(i)=>setState(()=>index=i!))),
        SectionTitle(tabs[index]=='Overview'?'Dashboard overview':tabs[index]=='Vendors'?'Vendor approvals':tabs[index],eyebrow:'ADMIN · SUBANG JAYA PILOT · DEMO DATA'),
        ...content(),
      ])),
    ]);
  });
  List<Widget> content()=>switch(index){
    0=>[metrics(),const SizedBox(height:18),const SectionTitle('Recent food listings'),...listingRows()],
    1=>[InfoCard(child:ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(child:Text('S')),
      title:Text(store.studentName),subtitle:Text(store.studentEmail),trailing:const StatusBadge('Demo')))],
    2=>[for(final v in store.vendors)InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(v.name,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)),const SizedBox(height:9),Text(v.address),
      const SizedBox(height:14),StatusBadge(v.status),
      if(v.status=='pending')Padding(padding:const EdgeInsets.only(top:16),child:Wrap(spacing:12,children:[
        FilledButton(onPressed:()=>store.approveVendor(v.id),child:const Text('Approve')),
        OutlinedButton(onPressed:()=>store.approveVendor(v.id,approve:false),child:const Text('Reject'))])),
    ]))],
    3=>listingRows(),
    4=>[if(store.reservations.isEmpty)const EmptyContent('No reservations yet','Make a reservation in the Student experience.'),
      for(final o in store.reservations)InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${o.id} · ${o.title}',style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:10),
        Text('${o.quantity} portions · ${money(o.total)} · ${o.pickup}'),const SizedBox(height:12),StatusBadge(o.status),
      ]))],
    5=>[metrics(),const SizedBox(height:15),const SectionTitle('The rescue so far'),
      for(final status in ['Reserved','Collected','Cancelled'])InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('$status: ${store.reservations.where((o)=>o.status==status).length}'),const SizedBox(height:14),
        LinearProgressIndicator(value:store.reservations.isEmpty?0:store.reservations.where((o)=>o.status==status).length/store.reservations.length,
          minHeight:10,borderRadius:BorderRadius.circular(6)),
      ])),const DemoNotice('Reports are calculated from this session’s sample data. No real revenue settlement.')],
    6=>[if(store.activity.isEmpty)const EmptyContent('A fresh start','Approvals, listing changes and reservations will appear here.'),
      for(final event in store.activity)InfoCard(child:Row(children:[const Icon(Icons.history,color:forest),const SizedBox(width:14),Expanded(child:Text(event))]))],
    _=>[const InfoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Service area: Subang Jaya'),SizedBox(height:16),Text('Vendor approval: Required'),SizedBox(height:16),
      Text('Payments: Simulated pay at pickup'),SizedBox(height:16),Text('Storage: In memory, this session only'),SizedBox(height:16),
      Text('Access: Demo role selection'),
    ])),const DemoNotice('These are sample settings. No backend, authentication or production access control is connected.')],
  };
}

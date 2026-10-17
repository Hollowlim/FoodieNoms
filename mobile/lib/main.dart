import 'package:flutter/material.dart';
import 'demo_store.dart';
import 'ui.dart';
import 'screens/student.dart';
import 'screens/vendor.dart';
import 'screens/admin.dart';

void main()=>runApp(const FoodieNomsApp());

class FoodieNomsApp extends StatefulWidget {
  const FoodieNomsApp({super.key,this.store});
  final DemoStore? store;
  @override
  State<FoodieNomsApp> createState()=>_FoodieNomsAppState();
}
class _FoodieNomsAppState extends State<FoodieNomsApp> {
  late final DemoStore store=widget.store??DemoStore();
  String? role;
  @override
  void dispose(){if(widget.store==null)store.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>MaterialApp(title:'FoodieNoms',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,
      colorScheme:ColorScheme.fromSeed(seedColor:forest).copyWith(primary:forest,surface:cream,onSurface:ink),
      appBarTheme:const AppBarTheme(backgroundColor:cream,foregroundColor:darkGreen,centerTitle:false),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(minimumSize:const Size(0,48),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
      inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:Color(0xFFE0E6DB))),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:Color(0xFFE0E6DB)))),
      cardTheme:const CardThemeData(color:Colors.white,elevation:0),
    ),home:role==null?ExperienceScreen(onChoose:(r)=>setState(()=>role=r)):
      RoleHome(key:ValueKey(role),role:role!,store:store,onSwitch:()=>setState(()=>role=null)));
}

class ExperienceScreen extends StatelessWidget {
  const ExperienceScreen({super.key,required this.onChoose});
  final ValueChanged<String> onChoose;
  @override
  Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:PageList(width:500,children:[
    const SizedBox(height:30),const Icon(Icons.shopping_bag_outlined,size:76,color:forest),
    const SizedBox(height:14),const Text('FoodieNoms',textAlign:TextAlign.center,
      style:TextStyle(color:forest,fontSize:31,fontWeight:FontWeight.w800)),
    const Text('Eat good. Save more.',textAlign:TextAlign.center,style:TextStyle(color:Colors.black54)),
    const SizedBox(height:42),const SectionTitle('Choose your experience',subtitle:'Good food. Less waste. One community.'),
    for(final r in ['Student','Vendor','Administrator']) Padding(padding:const EdgeInsets.only(bottom:14),
      child:OutlinedButton(onPressed:()=>onChoose(r),style:OutlinedButton.styleFrom(
        backgroundColor:Colors.white,padding:const EdgeInsets.all(20),side:const BorderSide(color:Color(0xFFE0E6DB)),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
        child:Row(children:[Icon(r=='Student'?Icons.eco_outlined:r=='Vendor'?Icons.storefront:Icons.admin_panel_settings_outlined),
          const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(r,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16)),const SizedBox(height:5),
            Text(r=='Student'?'Discover affordable surplus food':r=='Vendor'?'List food and manage pickup orders':'Manage and moderate the platform',
              style:const TextStyle(fontSize:11,color:Colors.black54))])),const Icon(Icons.chevron_right)]))),
    const SizedBox(height:16),const DemoNotice('Android app demo · Sample data only. No account needed. Changes last until the app is closed or reset.'),
    const Text('FoodieNoms • Subang Jaya pilot',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Colors.black45)),
  ])));
}

class RoleHome extends StatefulWidget {
  const RoleHome({super.key,required this.role,required this.store,required this.onSwitch});
  final String role;
  final DemoStore store;
  final VoidCallback onSwitch;
  @override
  State<RoleHome> createState()=>_RoleHomeState();
}
class _RoleHomeState extends State<RoleHome> {
  int index=0;
  @override
  Widget build(BuildContext context){
    final student=widget.role=='Student';final admin=widget.role=='Administrator';
    final labels=student?['Discover','Nearby','Orders','Profile']:['Dashboard','Listings','Orders','Profile'];
    final icons=student?[Icons.home_outlined,Icons.map_outlined,Icons.receipt_long_outlined,Icons.person_outline]:
      [Icons.dashboard_outlined,Icons.add_box_outlined,Icons.receipt_long_outlined,Icons.person_outline];
    return Scaffold(appBar:AppBar(title:const Text('FoodieNoms',style:TextStyle(fontWeight:FontWeight.w800,fontSize:21)),actions:[
      const Padding(padding:EdgeInsets.symmetric(vertical:18),child:Text('DEMO',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:forest))),
      IconButton(tooltip:'Demo menu',icon:const Icon(Icons.more_vert),onPressed:()async{
        final action=await showModalBottomSheet<String>(context:context,builder:(sheet)=>SafeArea(
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            ListTile(leading:const Icon(Icons.switch_account_outlined),title:const Text('Switch experience'),
              onTap:()=>Navigator.pop(sheet,'switch')),
            ListTile(leading:const Icon(Icons.restart_alt),title:const Text('Reset demo'),
              onTap:()=>Navigator.pop(sheet,'reset')),
          ])));
        if(!mounted)return;
        if(action=='switch'){widget.onSwitch();return;}
        if(action=='reset'&&await confirm(context,'Reset all demo listings, reservations and profile changes?')){
          if(!mounted)return;
          widget.store.reset();widget.onSwitch();
        }
      }),
    ]),body:SafeArea(child:AnimatedBuilder(animation:widget.store,builder:(c,_)=>
      admin?AdminScreen(store:widget.store):student?
        switch(index){0=>DiscoverScreen(store:widget.store),1=>NearbyScreen(store:widget.store),
          2=>OrdersScreen(store:widget.store),_=>ProfileScreen(store:widget.store)}:
        switch(index){0=>VendorDashboard(store:widget.store),1=>VendorListings(store:widget.store),
          2=>OrdersScreen(store:widget.store,vendorMode:true),_=>ProfileScreen(store:widget.store,vendorMode:true)})),
      bottomNavigationBar:admin?null:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),
        destinations:List.generate(labels.length,(i)=>NavigationDestination(icon:Icon(icons[i]),label:labels[i]))));
  }
}

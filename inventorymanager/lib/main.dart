import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class Item {
  final String name;
  final int quantity;

  Item({required this.name, required this.quantity});
}

class Inventory {
  List<Item> items;

  Inventory(this.items);

  void addItem(Item item) {
    items.add(item);
  }

  void editItem(int index, Item item) {
    items[index] = item;
  }

  void deleteItem(int index) {
    items.removeAt(index);
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GFG Inventory Manager',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: InventoryScreen(),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final itemNameController = TextEditingController();
  final quantityController = TextEditingController();
  final CollectionReference _inventory =
      FirebaseFirestore.instance.collection('Inventory');

  late Inventory inventory;
  int selectedIndex = -1;



 Future<void> _createOrUpdate([DocumentSnapshot? documentSnapshot]) async {
    String action = 'create';
    if (documentSnapshot != null) {
      action = 'update';
     itemNameController.text = documentSnapshot['Item Name'];
      quantityController.text = documentSnapshot['quantity'].toString();
    }

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: itemNameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'quantity"',
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                child: Text(action == 'create' ? 'Create' : 'Update'),
                onPressed: () async {
                  String name = itemNameController.text;
                  double price = double.parse(quantityController.text);
                  if (name.isNotEmpty && price != null) {
                    if (action == 'create') {
                      // Persist a new product to Firestore
                      await _inventory.add({"Item Name": name, "quantity": price});
                    }

                    if (action == 'update') {
                      // Update the product
                      await _inventory.doc(documentSnapshot!.id).update({
                        "Item Name": name,
                        "quantity": price,
                      });
                    }

                    itemNameController.text = '';
                    quantityController.text = '';

                    Navigator.of(context).pop();
                  }
                },
              )
            ],
          ),
        );
      },
    );
  }








  @override
  void initState() {
    super.initState();
    loadInventory();
  }

  Future<void> loadInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList('Inventory') ?? [];
    setState(() {
      inventory = Inventory(
        items.map((item) {
          final parts = item.split(':');
          return Item(name: parts[0], quantity: int.parse(parts[1]));
        }).toList(),
      );
    });
  }

  Future<void> saveInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final items =
        inventory.items.map((item) => '${item.name}:${item.quantity}').toList();
    prefs.setStringList('Inventory', items);
  }

  void addItem() {
    final name = itemNameController.text;
    final quantity = int.tryParse(quantityController.text) ?? 0;

    if (name.isNotEmpty && quantity > 0) {
      setState(() {
        inventory.addItem(Item(name: name, quantity: quantity));
        itemNameController.clear();
        quantityController.clear();
        saveInventory();
      });
    }
  }

  void editItem() {
    final name = itemNameController.text;
    final quantity = int.tryParse(quantityController.text) ?? 0;

    if (name.isNotEmpty && quantity > 0) {
      setState(() {
        inventory.editItem(selectedIndex, Item(name: name, quantity: quantity));
        itemNameController.clear();
        quantityController.clear();
        saveInventory();
        selectedIndex = -1;
      });
    }
  }

  void deleteItem(int index) {
    setState(() {
      inventory.deleteItem(index);
      saveInventory();
    });
  }

  // Deleting a product by id
  Future<void> _deleteItem(String productId) async {
    await _inventory.doc(productId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have successfully deleted a product'),
      ),
    );
  }

  void showEditDialog(int index) {
    itemNameController.text = inventory.items[index].name;
    quantityController.text = inventory.items[index].quantity.toString();
    selectedIndex = index;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: itemNameController,
                  decoration: InputDecoration(labelText: 'Item Name'),
                ),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'quantity'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                editItem();
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRUD operations'),
      ),
      // Using StreamBuilder to display all products from Firestore in real-time
      body: StreamBuilder(
        stream: _inventory.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> streamSnapshot) {
          if (streamSnapshot.hasData) {
            return ListView.builder(
              itemCount: streamSnapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final DocumentSnapshot documentSnapshot =
                streamSnapshot.data!.docs[index];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(documentSnapshot['Item Name']),
                    subtitle: Text(documentSnapshot['quantity'].toString()),
                    trailing: SizedBox(
                      width: 100,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _createOrUpdate(documentSnapshot),
                          ),
                          // IconButton(
                          //   icon: const Icon(Icons.delete),
                          //   onPressed: () =>
                          //       deleteItem(documentSnapshot.id),
                          // ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }

          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
      // Add new product
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createOrUpdate(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

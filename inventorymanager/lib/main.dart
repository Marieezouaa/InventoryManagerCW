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
                  decoration: InputDecoration(labelText: 'Quantity'),
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
        title: Text('GFG Inventory Manager'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: inventory.items.length,
              itemBuilder: (context, index) {
                final item = inventory.items[index];
                return Card(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text('Quantity: ${item.quantity}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            showEditDialog(index);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            deleteItem(index);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: itemNameController,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(), labelText: 'Item Name'),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(), labelText: 'Quantity'),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: selectedIndex == -1 ? addItem : editItem,
                  child: Text(selectedIndex == -1 ? 'Add Item' : 'Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://iwjnkguatgumdcfpytpu.supabase.co';
const supabasePublishableKey =
    'sb_publishable__P3S6gs7rhb-YmQlzzCG5w_KbbtpKXD';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );

  runApp(const MarketplaceApp());
}

class MarketplaceApp extends StatelessWidget {
  const MarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Preço Nexo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  String search = '';
  bool loading = true;

  List<Map<String, dynamic>> products = [];

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        products = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar produtos: $e');

      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = products.where((product) {
      final name = product['name']?.toString().toLowerCase() ?? '';
      return name.contains(search.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preço Nexo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: currentIndex == 0
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'O que você está procurando?',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        search = value;
                      });
                    },
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Categorias',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: const [
                      CategoryIcon(
                        icon: Icons.phone_android,
                        title: 'Eletrônicos',
                      ),
                      CategoryIcon(
                        icon: Icons.checkroom,
                        title: 'Moda',
                      ),
                      CategoryIcon(
                        icon: Icons.home,
                        title: 'Casa',
                      ),
                      CategoryIcon(
                        icon: Icons.sports_soccer,
                        title: 'Esportes',
                      ),
                      CategoryIcon(
                        icon: Icons.directions_car,
                        title: 'Veículos',
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 15, 16, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ofertas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : filteredProducts.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum produto encontrado.',
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.68,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];

                                final name =
                                    product['name']?.toString() ?? 'Produto';

                                final price =
                                    product['price']?.toString() ?? '0.00';

                                final imageUrl =
                                    product['image_url']?.toString() ?? '';

                                final seller =
                                    product['seller_name']?.toString() ?? '';

                                final discount =
                                    product['discount_percentage']
                                            ?.toString() ??
                                        '';

                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text(name),
                                            content: const Text(
                                              'Produto selecionado.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: const Text('Fechar'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: imageUrl.isNotEmpty
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        12,
                                                      ),
                                                      child: Image.network(
                                                        imageUrl,
                                                        fit: BoxFit.contain,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) {
                                                          return const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            size: 50,
                                                            color: Colors.grey,
                                                          );
                                                        },
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.shopping_bag,
                                                      size: 55,
                                                      color: Colors.grey,
                                                    ),
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          Text(
                                            name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(height: 4),

                                          Text(
                                            'R\$ $price',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          if (discount.isNotEmpty &&
                                              discount != '0')
                                            Text(
                                              '$discount% OFF',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                          if (seller.isNotEmpty)
                                            Text(
                                              seller,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            )
          : Center(
              child: Text(
                currentIndex == 1 ? '❤️ Favoritos' : '👤 Minha conta',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Conta',
          ),
        ],
      ),
    );
  }
}

class CategoryIcon extends StatelessWidget {
  final IconData icon;
  final String title;

  const CategoryIcon({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 85,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            child: Icon(icon),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

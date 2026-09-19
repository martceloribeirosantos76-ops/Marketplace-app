import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://iwjnkguatgumdcfpytpu.supabase.co';

// IMPORTANTE:
// Se você já tinha uma chave anon/public funcionando no main.dart,
// mantenha a mesma chave que já estava no seu projeto.
const supabaseAnonKey = 'sb_publishable__P3S6gs7rhb-YmQlzzCG5w_KbbtpKXD;.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const PrecoNexoApp());
}

class PrecoNexoApp extends StatelessWidget {
  const PrecoNexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Preço Nexo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
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
  bool carregando = true;
  String? erro;
  List<Map<String, dynamic>> produtos = [];

  @override
  void initState() {
    super.initState();
    carregarProdutos();
  }

  Future<void> carregarProdutos() async {
    try {
      setState(() {
        carregando = true;
        erro = null;
      });

      final resposta = await Supabase.instance.client
          .from('products')
          .select(
            'id,name,condition,category_id,seller_name,price,store_name,'
            'is_sponsored,created_at,affiliate_url,external_product_id,'
            'original_price,affiliate_network,discount_percentage',
          )
          .order('created_at', ascending: false);

      setState(() {
        produtos = List<Map<String, dynamic>>.from(resposta);
        carregando = false;
      });
    } catch (e) {
      setState(() {
        carregando = false;
        erro = e.toString();
      });
    }
  }

  String formatarPreco(dynamic valor) {
    if (valor == null) return 'Preço não informado';

    final numero = double.tryParse(valor.toString());

    if (numero == null) {
      return 'Preço não informado';
    }

    return 'R\$ ${numero.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> abrirOferta(String? url) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link da oferta ainda não disponível.'),
        ),
      );
      return;
    }

    // O link será conectado à abertura externa
    // na próxima etapa da monetização.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Oferta: $url'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preço Nexo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: carregarProdutos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar produtos',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Categorias',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (carregando)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (erro != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Não foi possível carregar os produtos.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        erro!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: carregarProdutos,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
            else if (produtos.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Nenhum produto encontrado.',
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: produtos.length,
                  itemBuilder: (context, index) {
                    final produto = produtos[index];

                    final nome =
                        produto['name']?.toString() ??
                        'Produto sem nome';

                    final loja =
                        produto['store_name']?.toString() ??
                        produto['seller_name']?.toString() ??
                        'Loja não informada';

                    final preco = formatarPreco(
                      produto['price'],
                    );

                    final desconto =
                        produto['discount_percentage'];

                    final rede =
                        produto['affiliate_network']
                            ?.toString() ??
                        'Shopee';

                    return Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 110,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                size: 52,
                                color: Colors.blueGrey,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              nome,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              loja,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              preco,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),

                            if (desconto != null)
                              Text(
                                'Desconto: $desconto%',
                                style: const TextStyle(
                                  color: Colors.red,
                                ),
                              ),

                            const Spacer(),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  abrirOferta(
                                    produto['affiliate_url']
                                        ?.toString(),
                                  );
                                },
                                child: Text(
                                  'Ver oferta • $rede',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

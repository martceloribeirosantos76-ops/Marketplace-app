import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl =
    'https://iwjnkguatgumdcfpytpu.supabase.co';

const supabaseAnonKey =
    'sb_publishable__P3S6gs7rhb-YmQlzzCG5w_KbbtpKXD';

const affiliateClickFunctionUrl =
    '$supabaseUrl/functions/v1/affiliate-click';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
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
            'original_price,affiliate_network,discount_percentage,'
            'image_url',
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
    if (valor == null) {
      return 'Preço não informado';
    }

    final numero = double.tryParse(valor.toString());

    if (numero == null) {
      return 'Preço não informado';
    }

    return 'R\$ ${numero.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> abrirOferta(
    Map<String, dynamic> produto,
  ) async {
    final productId = produto['id'];
    final affiliateUrl =
        produto['affiliate_url']?.toString();

    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID do produto não encontrado.'),
        ),
      );
      return;
    }

    final id = int.tryParse(productId.toString());

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID do produto inválido.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abrindo oferta...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final uri = Uri.parse(
        '$affiliateClickFunctionUrl?product_id=$id',
      );

      final request = http.Request('GET', uri)
        ..followRedirects = false;

      request.headers.addAll({
        'Authorization': 'Bearer $supabaseAnonKey',
        'apikey': supabaseAnonKey,
      });

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(
        streamedResponse,
      );

      String? destino;

      if (response.statusCode >= 300 &&
          response.statusCode < 400) {
        destino = response.headers['location'];
      }

      if (destino == null &&
          response.body.isNotEmpty) {
        try {
          final json = jsonDecode(response.body);

          if (json is Map &&
              json['affiliate_url'] != null) {
            destino =
                json['affiliate_url'].toString();
          }
        } catch (_) {
          // Resposta não é JSON.
        }
      }

      if (destino == null &&
          affiliateUrl != null &&
          affiliateUrl.trim().isNotEmpty) {
        destino = affiliateUrl;
      }

      if (destino != null &&
          destino.trim().isNotEmpty) {
        await _abrirLink(destino);
        return;
      }

      throw Exception(
        'Não foi possível obter o link da oferta.',
      );
    } catch (e) {
      if (affiliateUrl != null &&
          affiliateUrl.trim().isNotEmpty) {
        await _abrirLink(affiliateUrl);
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao abrir a oferta: $e',
          ),
        ),
      );
    }
  }

  Future<void> _abrirLink(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link da oferta inválido.'),
        ),
      );

      return;
    }

    final abriu = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!abriu && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir a oferta.',
          ),
        ),
      );
    }
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
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
                    mainAxisAlignment:
                        MainAxisAlignment.center,
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
                        child: const Text(
                          'Tentar novamente',
                        ),
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
                        produto['store_name']
                                ?.toString() ??
                            produto['seller_name']
                                ?.toString() ??
                            'Loja não informada';

                    final preco =
                        formatarPreco(produto['price']);

                    final desconto =
                        produto['discount_percentage'];

                    final rede =
                        produto['affiliate_network']
                                ?.toString() ??
                            'Shopee';

                    final imagem =
                        produto['image_url']?.toString();

                    return Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 110,
                              width: double.infinity,
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.grey.shade100,
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                              child: imagem != null &&
                                      imagem.trim().isNotEmpty
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                        12,
                                      ),
                                      child:
                                          Image.network(
                                        imagem,
                                        width:
                                            double.infinity,
                                        height: 110,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return const Icon(
                                            Icons
                                                .broken_image_outlined,
                                            size: 52,
                                            color:
                                                Colors.blueGrey,
                                          );
                                        },
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .shopping_bag_outlined,
                                      size: 52,
                                      color:
                                          Colors.blueGrey,
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              nome,
                              maxLines: 3,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              loja,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              preco,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight:
                                    FontWeight.bold,
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
                                  abrirOferta(produto);
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

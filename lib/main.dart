import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl = 'https://iwjnkguatgumdcfpytpu.supabase.co';

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

  String busca = '';
  int? categoriaSelecionada;

  final Map<int, String> categorias = {
    1: 'Eletrônicos',
    2: 'Informática',
    3: 'Celulares e Acessórios',
    4: 'Casa',
    5: 'Eletrodomésticos',
    6: 'Moda',
    7: 'Beleza',
    8: 'Esportes e Lazer',
    9: 'Automotivo',
    10: 'Ferramentas',
    11: 'Brinquedos',
    12: 'Games',
    13: 'Pet',
    14: 'Saúde',
    15: 'Bebês e Crianças',
    16: 'Livros e Papelaria',
    17: 'Acessórios',
    18: 'Outros',
  };

  @override
  void initState() {
    super.initState();
    carregarProdutos();
  }

  List<MapEntry<int, String>> get categoriasDisponiveis {
    final ids = produtos
        .map(
          (produto) => int.tryParse(
            produto['category_id']?.toString() ?? '',
          ),
        )
        .whereType<int>()
        .toSet();

    return categorias.entries
        .where((categoria) => ids.contains(categoria.key))
        .toList();
  }

  List<Map<String, dynamic>> get produtosFiltrados {
    final termo = busca.trim().toLowerCase();

    return produtos.where((produto) {
      final nome =
          produto['name']?.toString().toLowerCase() ?? '';

      final loja =
          produto['store_name']?.toString().toLowerCase() ??
              produto['seller_name']?.toString().toLowerCase() ??
              '';

      final correspondeBusca =
          termo.isEmpty ||
          nome.contains(termo) ||
          loja.contains(termo);

      final categoriaProduto = int.tryParse(
        produto['category_id']?.toString() ?? '',
      );

      final correspondeCategoria =
          categoriaSelecionada == null ||
          categoriaProduto == categoriaSelecionada;

      return correspondeBusca && correspondeCategoria;
    }).toList();
  }

  Future<void> carregarProdutos() async {
    if (mounted) {
      setState(() {
        carregando = true;
        erro = null;
      });
    }

    try {
      final client = Supabase.instance.client;

      const campos =
          'id,'
          'name,'
          'condition,'
          'category_id,'
          'seller_name,'
          'price,'
          'store_name,'
          'is_sponsored,'
          'created_at,'
          'affiliate_url,'
          'external_product_id,'
          'original_price,'
          'affiliate_network,'
          'discount_percentage,'
          'image_url,'
          'stock';

      final List<Map<String, dynamic>> todosProdutos = [];

      const tamanhoPagina = 50;
      int inicio = 0;

      while (true) {
        final fim = inicio + tamanhoPagina - 1;

        final resposta = await client
    .from('products')
    .select(campos)
    .eq('is_active', true)
    .order('created_at', ascending: false)
    .range(inicio, fim);


        final pagina =
            List<Map<String, dynamic>>.from(resposta);

        todosProdutos.addAll(pagina);

        if (pagina.length < tamanhoPagina) {
          break;
        }

        inicio += tamanhoPagina;
      }

      if (!mounted) return;

      setState(() {
        produtos = todosProdutos;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

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

  String nomeRede(Map<String, dynamic> produto) {
    final rede =
        produto['affiliate_network']?.toString().trim();

    if (rede == null || rede.isEmpty) {
      return 'Oferta';
    }

    if (rede.toLowerCase() == 'awin') {
      return 'Awin';
    }

    if (rede.toLowerCase() == 'shopee') {
      return 'Shopee';
    }

    return rede;
  }

  Color corRede(Map<String, dynamic> produto) {
    final rede =
        produto['affiliate_network']?.toString().toLowerCase();

    if (rede == 'awin') {
      return Colors.deepPurple;
    }

    if (rede == 'shopee') {
      return Colors.orange.shade800;
    }

    return Colors.blue;
  }

  Future<void> abrirOferta(
    Map<String, dynamic> produto,
  ) async {
    final productId = produto['id'];

    final affiliateUrl =
        produto['affiliate_url']?.toString().trim();

    if (productId == null) {
      _mostrarMensagem('ID do produto não encontrado.');
      return;
    }

    final id = int.tryParse(productId.toString());

    if (id == null) {
      _mostrarMensagem('ID do produto inválido.');
      return;
    }

    _mostrarMensagem(
      'Abrindo oferta...',
      duracao: const Duration(seconds: 2),
    );

    String? destino;

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

      final response =
          await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 300 &&
          response.statusCode < 400) {
        destino = response.headers['location'];
      }

      if (destino == null && response.body.isNotEmpty) {
        try {
          final json = jsonDecode(response.body);

          if (json is Map) {
            if (json['affiliate_url'] != null) {
              destino =
                  json['affiliate_url'].toString();
            } else if (json['url'] != null) {
              destino = json['url'].toString();
            } else if (json['redirect_url'] != null) {
              destino =
                  json['redirect_url'].toString();
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    if (destino == null || destino.trim().isEmpty) {
      destino = affiliateUrl;
    }

    if (destino == null || destino.trim().isEmpty) {
      _mostrarMensagem(
        'Este produto ainda não possui link de afiliado.',
      );
      return;
    }

    await _abrirLink(destino);
  }

  Future<void> _abrirLink(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _mostrarMensagem('Link da oferta inválido.');
      return;
    }

    try {
      final abriu = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!abriu) {
        _mostrarMensagem(
          'Não foi possível abrir a oferta.',
        );
      }
    } catch (_) {
      _mostrarMensagem(
        'Erro ao abrir a oferta.',
      );
    }
  }

  void _mostrarMensagem(
    String mensagem, {
    Duration duracao = const Duration(seconds: 3),
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration: duracao,
      ),
    );
  }

  Widget _imagemProduto(String? imagem) {
    if (imagem == null || imagem.trim().isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 56,
          color: Colors.blueGrey.shade300,
        ),
      );
    }

    final url = imagem.trim();

    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        cacheWidth: 700,
        loadingBuilder: (
          context,
          child,
          loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }

          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 48,
                color: Colors.blueGrey.shade300,
              ),
              const SizedBox(height: 6),
              Text(
                'Imagem indisponível',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _produtoCard(
    BuildContext context,
    Map<String, dynamic> produto,
  ) {
    final nome =
        produto['name']?.toString() ??
            'Produto sem nome';

    final storeName =
        produto['store_name']?.toString().trim();

    final sellerName =
        produto['seller_name']?.toString().trim();

    final loja =
        storeName != null && storeName.isNotEmpty
            ? storeName
            : sellerName != null && sellerName.isNotEmpty
                ? sellerName
                : 'Loja não informada';

    final preco = formatarPreco(produto['price']);

    final desconto =
        produto['discount_percentage'];

    final rede = nomeRede(produto);

    final imagem =
        produto['image_url']?.toString().trim();

    final temAfiliado =
        produto['affiliate_url']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true;

    final patrocinado =
        produto['is_sponsored'] == true;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: _imagemProduto(imagem),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                12,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (patrocinado)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Patrocinado',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: corRede(produto)
                              .withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Text(
                          rede,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                corRede(produto),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nome,
                    maxLines: 3,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loja,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preco,
                    style: const TextStyle(
                      fontSize: 20,
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
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child:
                        ElevatedButton.icon(
                      onPressed: temAfiliado
                          ? () =>
                              abrirOferta(produto)
                          : null,
                      icon: const Icon(
                        Icons.open_in_new,
                        size: 18,
                      ),
                      label: Text(
                        temAfiliado
                            ? 'Ver oferta'
                            : 'Sem afiliado',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final produtosExibidos =
        produtosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preço Nexo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: carregarProdutos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar produtos',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: carregarProdutos,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Encontre ofertas',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${produtos.length} produtos disponíveis',
                style: TextStyle(
                  color:
                      Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                decoration:
                    InputDecoration(
                  hintText:
                      'Buscar produtos ou lojas',
                  prefixIcon:
                      const Icon(Icons.search),
                  suffixIcon:
                      busca.isNotEmpty
                          ? IconButton(
                              icon:
                                  const Icon(
                                Icons.clear,
                              ),
                              onPressed: () {
                                setState(() {
                                  busca = '';
                                });
                              },
                            )
                          : null,
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                onChanged: (valor) {
                  setState(() {
                    busca = valor;
                  });
                },
              ),
              const SizedBox(height: 14),
              if (categoriasDisponiveis
                  .isNotEmpty)
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection:
                        Axis.horizontal,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          right: 8,
                        ),
                        child: ChoiceChip(
                          label:
                              const Text(
                            'Todas',
                          ),
                          selected:
                              categoriaSelecionada ==
                                  null,
                          onSelected: (_) {
                            setState(() {
                              categoriaSelecionada =
                                  null;
                            });
                          },
                        ),
                      ),
                      ...categoriasDisponiveis
                          .map(
                        (categoria) =>
                            Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            right: 8,
                          ),
                          child: ChoiceChip(
                            label: Text(
                              categoria.value,
                            ),
                            selected:
                                categoriaSelecionada ==
                                    categoria
                                        .key,
                            onSelected: (_) {
                              setState(() {
                                categoriaSelecionada =
                                    categoria
                                        .key;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    _conteudoProdutos(
                  produtosExibidos,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudoProdutos(
    List<Map<String, dynamic>>
        produtosExibidos,
  ) {
    if (carregando) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (erro != null) {
      return Center(
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 52,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível carregar os produtos.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                erro!,
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    carregarProdutos,
                child: const Text(
                  'Tentar novamente',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (produtos.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum produto encontrado.',
          style:
              TextStyle(fontSize: 18),
        ),
      );
    }

    if (produtosExibidos.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum produto encontrado para este filtro.',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(fontSize: 18),
        ),
      );
    }

    return GridView.builder(
      padding:
          const EdgeInsets.only(
        bottom: 20,
      ),
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 455,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount:
          produtosExibidos.length,
      itemBuilder:
          (context, index) {
        return _produtoCard(
          context,
          produtosExibidos[index],
        );
      },
    );
  }
}

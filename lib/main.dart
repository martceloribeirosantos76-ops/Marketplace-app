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

      final rede =
          produto['affiliate_network']?.toString().toLowerCase() ??
              '';

      final correspondeBusca =
          termo.isEmpty ||
          nome.contains(termo) ||
          loja.contains(termo) ||
          rede.contains(termo);

      final categoriaProduto = int.tryParse(
        produto['category_id']?.toString() ?? '',
      );

      final correspondeCategoria =
          categoriaSelecionada == null ||
          categoriaProduto == categoriaSelecionada;

      return correspondeBusca && correspondeCategoria;
    }).toList();
  }

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

      /*
       * IMPORTANTE:
       * Não filtramos por stock.
       * Não filtramos por uma rede específica.
       *
       * O projeto trabalha com vários afiliados:
       * - AWIN
       * - SHOPEE
       *
       * Portanto, carregamos todos os produtos.
       */
      final resposta = await Supabase.instance.client
          .from('products')
          .select(
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
            'image_url',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;

      final lista = List<Map<String, dynamic>>.from(resposta);

      /*
       * Mantemos produtos que tenham pelo menos uma forma
       * válida de oferta:
       *
       * 1. affiliate_url diretamente em products
       * OU
       * 2. registro correspondente em affiliate_products
       *
       * Como nem todos os produtos antigos possuem affiliate_url,
       * primeiro tentamos usar os dados existentes em products.
       *
       * Não descartamos produtos simplesmente porque stock = 0.
       */

      setState(() {
        produtos = lista;
        carregando = false;

        if (categoriaSelecionada != null &&
            !categoriasDisponiveis.any(
              (categoria) =>
                  categoria.key == categoriaSelecionada,
            )) {
          categoriaSelecionada = null;
        }
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

  String nomeRede(dynamic valor) {
    final rede = valor?.toString().trim().toLowerCase();

    if (rede == 'awin') {
      return 'AWIN';
    }

    if (rede == 'shopee') {
      return 'Shopee';
    }

    if (rede == null || rede.isEmpty) {
      return 'Oferta';
    }

    return rede.toUpperCase();
  }

  Color corRede(dynamic valor) {
    final rede = valor?.toString().trim().toLowerCase();

    if (rede == 'awin') {
      return Colors.deepPurple;
    }

    if (rede == 'shopee') {
      return Colors.deepOrange;
    }

    return Colors.blue;
  }

  Future<void> abrirOferta(
    Map<String, dynamic> produto,
  ) async {
    final productId = produto['id'];

    final affiliateUrl =
        produto['affiliate_url']?.toString();

    if (productId == null) {
      _mostrarMensagem(
        'ID do produto não encontrado.',
      );
      return;
    }

    final id = int.tryParse(productId.toString());

    if (id == null) {
      _mostrarMensagem(
        'ID do produto inválido.',
      );
      return;
    }

    _mostrarMensagem(
      'Abrindo oferta...',
      duracao: const Duration(seconds: 2),
    );

    try {
      final uri = Uri.parse(
        '$affiliateClickFunctionUrl?product_id=$id',
      );

      final request = http.Request(
        'GET',
        uri,
      )..followRedirects = false;

      request.headers.addAll({
        'Authorization':
            'Bearer $supabaseAnonKey',
        'apikey': supabaseAnonKey,
      });

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      String? destino;

      if (response.statusCode >= 300 &&
          response.statusCode < 400) {
        destino =
            response.headers['location'];
      }

      if (destino == null &&
          response.body.isNotEmpty) {
        try {
          final json =
              jsonDecode(response.body);

          if (json is Map &&
              json['affiliate_url'] != null) {
            destino =
                json['affiliate_url'].toString();
          }

          if (destino == null &&
              json is Map &&
              json['url'] != null) {
            destino =
                json['url'].toString();
          }
        } catch (_) {
          // Resposta não é JSON.
        }
      }

      /*
       * Fallback:
       * caso a Edge Function não retorne o redirect,
       * usamos o affiliate_url salvo no produto.
       */
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
      /*
       * Mesmo que a Edge Function falhe,
       * não impedimos o usuário de acessar
       * uma oferta que já possui affiliate_url.
       */
      if (affiliateUrl != null &&
          affiliateUrl.trim().isNotEmpty) {
        await _abrirLink(affiliateUrl);
        return;
      }

      _mostrarMensagem(
        'Erro ao abrir a oferta.',
      );
    }
  }

  Future<void> _abrirLink(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      _mostrarMensagem(
        'Link da oferta inválido.',
      );
      return;
    }

    final abriu = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!abriu) {
      _mostrarMensagem(
        'Não foi possível abrir a oferta.',
      );
    }
  }

  void _mostrarMensagem(
    String mensagem, {
    Duration duracao =
        const Duration(seconds: 3),
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration: duracao,
      ),
    );
  }

  Widget construirImagem(String? imagem) {
    if (imagem == null ||
        imagem.trim().isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const Icon(
          Icons.shopping_bag_outlined,
          size: 52,
          color: Colors.blueGrey,
        ),
      );
    }

    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Image.network(
        imagem,
        width: double.infinity,
        height: 180,
        fit: BoxFit.contain,
        loadingBuilder:
            (context, child, progress) {
          if (progress == null) {
            return child;
          }

          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        errorBuilder:
            (context, error, stackTrace) {
          return const Icon(
            Icons.broken_image_outlined,
            size: 52,
            color: Colors.blueGrey,
          );
        },
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
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip:
                'Atualizar produtos',
          ),
        ],
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Preço Nexo',
              style: TextStyle(
                fontSize: 26,
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

            const SizedBox(height: 16),

            TextField(
              decoration:
                  InputDecoration(
                hintText:
                    'Buscar produtos',
                prefixIcon:
                    const Icon(
                  Icons.search,
                ),
                suffixIcon:
                    busca.isNotEmpty
                        ? IconButton(
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                            onPressed:
                                () {
                              setState(
                                () {
                                  busca =
                                      '';
                                },
                              );
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

            const SizedBox(height: 16),

            if (categoriasDisponiveis
                .isNotEmpty) ...[
              const Text(
                'Categorias',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

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
                            const EdgeInsets.only(
                          right: 8,
                        ),
                        child:
                            ChoiceChip(
                          label:
                              Text(
                            categoria.value,
                          ),
                          selected:
                              categoriaSelecionada ==
                                  categoria.key,
                          onSelected:
                              (_) {
                            setState(
                              () {
                                categoriaSelecionada =
                                    categoria
                                        .key;
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            if (carregando)
              const Expanded(
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (erro != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      const Icon(
                        Icons
                            .error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      const Text(
                        'Não foi possível carregar os produtos.',
                        textAlign:
                            TextAlign.center,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        erro!,
                        textAlign:
                            TextAlign.center,
                        style:
                            const TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey,
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      ElevatedButton(
                        onPressed:
                            carregarProdutos,
                        child:
                            const Text(
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
            else if (produtosExibidos
                .isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Nenhum produto encontrado para este filtro.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child:
                    GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent:
                        360,
                    childAspectRatio:
                        0.72,
                    crossAxisSpacing:
                        16,
                    mainAxisSpacing:
                        16,
                  ),
                  itemCount:
                      produtosExibidos
                          .length,
                  itemBuilder:
                      (context, index) {
                    final produto =
                        produtosExibidos[
                            index];

                    final nome =
                        produto[
                                    'name']
                                ?.toString() ??
                            'Produto sem nome';

                    final loja =
                        produto[
                                    'store_name']
                                ?.toString() ??
                            produto[
                                    'seller_name']
                                ?.toString() ??
                            'Loja não informada';

                    final preco =
                        formatarPreco(
                      produto['price'],
                    );

                    final desconto =
                        produto[
                            'discount_percentage'];

                    final rede =
                        nomeRede(
                      produto[
                          'affiliate_network'],
                    );

                    final cor =
                        corRede(
                      produto[
                          'affiliate_network'],
                    );

                    final imagem =
                        produto[
                                'image_url']
                            ?.toString();

                    final possuiOferta =
                        produto[
                                    'affiliate_url']
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true;

                    return Card(
                      elevation: 2,
                      clipBehavior:
                          Clip.antiAlias,
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          SizedBox(
                            height: 180,
                            width:
                                double.infinity,
                            child:
                                construirImagem(
                              imagem,
                            ),
                          ),

                          Expanded(
                            child:
                                Padding(
                              padding:
                                  const EdgeInsets.all(
                                14,
                              ),
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal:
                                          8,
                                      vertical:
                                          4,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color: cor
                                          .withValues(
                                        alpha:
                                            0.12,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(
                                        20,
                                      ),
                                    ),
                                    child:
                                        Text(
                                      rede,
                                      style:
                                          TextStyle(
                                        color:
                                            cor,
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize:
                                            12,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        8,
                                  ),

                                  Text(
                                    nome,
                                    maxLines:
                                        3,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          16,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        6,
                                  ),

                                  Text(
                                    loja,
                                    maxLines:
                                        1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.grey.shade700,
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        8,
                                  ),

                                  Text(
                                    preco,
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          21,
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          Colors.green,
                                    ),
                                  ),

                                  if (desconto !=
                                      null)
                                    Text(
                                      'Desconto: $desconto%',
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.red,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),

                                  const Spacer(),

                                  SizedBox(
                                    width:
                                        double.infinity,
                                    child:
                                        ElevatedButton(
                                      onPressed:
                                          possuiOferta
                                              ? () {
                                                  abrirOferta(
                                                    produto,
                                                  );
                                                }
                                              : null,
                                      child:
                                          Text(
                                        possuiOferta
                                            ? 'Ver oferta • $rede'
                                            : 'Oferta indisponível',
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
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
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

  // Paginação: busca 50 produtos por vez e carrega mais ao rolar.
  static const int tamanhoPagina = 50;
  int _proximoInicio = 0;
  bool _temMais = true;
  bool _carregandoMais = false;
  int _geracao = 0;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _buscaController =
      TextEditingController();
  Timer? _debounce;

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
    _scrollController.addListener(_aoRolar);
    carregarProdutos(reiniciar: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_aoRolar);
    _scrollController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  void _aoRolar() {
    if (!_scrollController.hasClients) return;

    final posicao = _scrollController.position;

    if (posicao.pixels >= posicao.maxScrollExtent - 800) {
      carregarProdutos();
    }
  }

  void _aoMudarBusca(String valor) {
    setState(() {
      busca = valor;
    });

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => carregarProdutos(reiniciar: true),
    );
  }

  void _limparBusca() {
    _debounce?.cancel();
    _buscaController.clear();

    setState(() {
      busca = '';
    });

    carregarProdutos(reiniciar: true);
  }

  void _selecionarCategoria(int? categoria) {
    setState(() {
      categoriaSelecionada = categoria;
    });

    carregarProdutos(reiniciar: true);
  }

  Future<void> carregarProdutos({
    bool reiniciar = false,
  }) async {
    if (reiniciar) {
      _geracao++;
      _proximoInicio = 0;
      _temMais = true;

      if (mounted) {
        setState(() {
          produtos = [];
          carregando = true;
          erro = null;
        });
      }
    } else {
      if (carregando || _carregandoMais || !_temMais) {
        return;
      }

      if (mounted) {
        setState(() {
          _carregandoMais = true;
        });
      }
    }

    final geracao = _geracao;
    final inicio = _proximoInicio;

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

      final termo = busca
          .trim()
          .replaceAll(RegExp(r'[,()%*\\]'), ' ')
          .trim();

      var consulta = client
          .from('products')
          .select(campos)
          .eq('is_active', true);

      if (categoriaSelecionada != null) {
        consulta = consulta.eq(
          'category_id',
          categoriaSelecionada!,
        );
      }

      if (termo.isNotEmpty) {
        consulta = consulta.or(
          'name.ilike.%$termo%,'
          'store_name.ilike.%$termo%,'
          'seller_name.ilike.%$termo%',
        );
      }

      final fim = inicio + tamanhoPagina - 1;

      final resposta = await consulta
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(inicio, fim);

      final pagina =
          List<Map<String, dynamic>>.from(resposta);

      // Ignora respostas de uma busca antiga.
      if (!mounted || geracao != _geracao) return;

      setState(() {
        produtos.addAll(pagina);
        _proximoInicio = inicio + tamanhoPagina;

        if (pagina.length < tamanhoPagina) {
          _temMais = false;
        }

        carregando = false;
        _carregandoMais = false;
      });
    } catch (e) {
      if (!mounted || geracao != _geracao) return;

      final semProdutos = produtos.isEmpty;

      setState(() {
        carregando = false;
        _carregandoMais = false;

        if (semProdutos) {
          erro = e.toString();
        }
      });

      if (!semProdutos) {
        _mostrarMensagem(
          'Erro ao carregar mais produtos.',
        );
      }
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

  bool ehMercadoLivre(Map<String, dynamic> produto) {
    final rede =
        produto['affiliate_network']?.toString().toLowerCase();

    return rede == 'mercadolivre';
  }
  Future<void> _compartilharWhatsApp(
    Map<String, dynamic> produto,
  ) async {
    final nome =
        produto['name']?.toString() ?? 'Oferta';

    const site =
        'https://martceloribeirosantos76-ops.github.io/Marketplace-app/';

    final texto =
        'Olha essa oferta que achei no Preço Nexo: $nome\n$site';

    await _abrirLink(
      'https://wa.me/?text=${Uri.encodeComponent(texto)}',
    );
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
  Widget _botoesSeguir() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () =>
              _abrirLink('https://t.me/PrecoNexoOfertas'),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Seguir no Telegram'),
        ),
        OutlinedButton.icon(
          onPressed: () => _abrirLink(
            'https://instagram.com/preconexo_achadinhos',
          ),
          icon: const Icon(
            Icons.camera_alt_outlined,
            size: 18,
          ),
          label: const Text('Seguir no Instagram'),
        ),
      ],
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

    final ml = ehMercadoLivre(produto);

    final desconto =
        produto['discount_percentage'];


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
                  if (!ml) ...[
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
                  ],
                  if (ml)
                    Text(
                      'Veja o preço atual no Mercado Livre',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Colors.grey.shade800,
                      ),
                    )
                  else
                    Text(
                      preco,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                if (!ml &&
    (double.tryParse(desconto?.toString() ?? '') ?? 0) > 0)
                    Text(
                      'Desconto: $desconto%',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: temAfiliado
                              ? () => abrirOferta(produto)
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
                      IconButton(
                        onPressed: () =>
                            _compartilharWhatsApp(produto),
                        icon: const Icon(Icons.share),
                        tooltip: 'Compartilhar no WhatsApp',
                      ),
                    ],
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
            onPressed: () =>
                carregarProdutos(reiniciar: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar produtos',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            carregarProdutos(reiniciar: true),
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
                _temMais
                    ? '${produtos.length}+ produtos'
                    : '${produtos.length} produtos',
                style: TextStyle(
                  color:
                      Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Publicidade: alguns links são de afiliados e '
                'podemos receber comissão se você comprar. '
                'Preços e disponibilidade podem mudar, '
                'confira na loja.',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Colors.grey.shade600,
                ),
              ),
                            const SizedBox(height: 10),
              _botoesSeguir(),
              const SizedBox(height: 14),
              TextField(
                controller: _buscaController,
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
                              onPressed:
                                  _limparBusca,
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
                onChanged: _aoMudarBusca,
              ),
              const SizedBox(height: 14),
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
                        onSelected: (_) =>
                            _selecionarCategoria(
                          null,
                        ),
                      ),
                    ),
                    ...categorias.entries.map(
                      (categoria) => Padding(
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
                                  categoria.key,
                          onSelected: (_) =>
                              _selecionarCategoria(
                            categoria.key,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _conteudoProdutos(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudoProdutos() {
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
                onPressed: () =>
                    carregarProdutos(
                  reiniciar: true,
                ),
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
      final comFiltro =
          busca.trim().isNotEmpty ||
              categoriaSelecionada != null;

      return Center(
        child: Text(
          comFiltro
              ? 'Nenhum produto encontrado para este filtro.'
              : 'Nenhum produto encontrado.',
          textAlign:
              TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
          ),
        ),
      );
    }

    final mostrarCarregandoMais =
        _carregandoMais;

    return GridView.builder(
      controller: _scrollController,
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
      itemCount: produtos.length +
          (mostrarCarregandoMais ? 1 : 0),
      itemBuilder:
          (context, index) {
        if (index >= produtos.length) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        return _produtoCard(
          context,
          produtos[index],
        );
      },
    );
  }
}

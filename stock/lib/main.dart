import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const StockManagerApp());

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────

String money(double v) {
  final negative = v < 0;
  final s = v.abs().round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final remaining = s.length - i;
    buf.write(s[i]);
    if (remaining > 1 && remaining % 3 == 1) buf.write(',');
  }
  return '${negative ? '-' : ''}$buf Frw';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String timeLabel(DateTime d) {
  final now = DateTime.now();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  if (sameDay(d, now)) return 'Today, $hh:$mm';
  if (sameDay(d, now.subtract(const Duration(days: 1)))) {
    return 'Yesterday, $hh:$mm';
  }
  return '${d.day}/${d.month}, $hh:$mm';
}

const categories = ['Groceries', 'Beverages', 'Household', 'Stationery', 'Other'];

IconData categoryIcon(String c) {
  switch (c) {
    case 'Groceries':
      return Icons.shopping_basket_rounded;
    case 'Beverages':
      return Icons.local_drink_rounded;
    case 'Household':
      return Icons.cleaning_services_rounded;
    case 'Stationery':
      return Icons.edit_note_rounded;
    default:
      return Icons.inventory_2_rounded;
  }
}

Color categoryColor(String c) {
  switch (c) {
    case 'Groceries':
      return Colors.orange.shade700;
    case 'Beverages':
      return Colors.blue.shade600;
    case 'Household':
      return Colors.purple.shade400;
    case 'Stationery':
      return Colors.pink.shade400;
    default:
      return Colors.blueGrey.shade500;
  }
}

String statusLabel(StockItem i) {
  if (i.quantity == 0) return 'Out of stock';
  if (i.quantity <= i.minStock) return 'Low stock';
  return 'In stock';
}

Color statusColor(StockItem i) {
  if (i.quantity == 0) return Colors.red.shade600;
  if (i.quantity <= i.minStock) return Colors.amber.shade800;
  return Colors.green.shade600;
}

// ─────────────────────────────────────────────────────────────
//  Models & store
// ─────────────────────────────────────────────────────────────

class StockItem {
  String id;
  String name;
  String category;
  int quantity;
  double price; // selling price
  double cost; // buying price
  int minStock; // low-stock threshold

  StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    required this.cost,
    required this.minStock,
  });
}

enum TxType { sale, restock, adjusted, added, removed }

class StockTx {
  final String id;
  final TxType type;
  final String itemName;
  final int qty;
  final double amount;
  final double profit;
  final DateTime date;

  StockTx({
    required this.id,
    required this.type,
    required this.itemName,
    required this.qty,
    required this.amount,
    required this.profit,
    required this.date,
  });
}

enum StatusFilter { all, low, out }

class StockStore extends ChangeNotifier {
  final List<StockItem> items = [];
  final List<StockTx> history = [];
  final Map<String, int> cart = {};
  StatusFilter statusFilter = StatusFilter.all;
  int _idCounter = 100;

  StockStore() {
    items.addAll([
      StockItem(id: '1', name: 'Rice (1 kg)', category: 'Groceries', quantity: 15, price: 1500, cost: 1200, minStock: 5),
      StockItem(id: '2', name: 'Cooking Oil (1 L)', category: 'Groceries', quantity: 3, price: 3500, cost: 3000, minStock: 5),
      StockItem(id: '3', name: 'Medicated Soap', category: 'Household', quantity: 20, price: 800, cost: 600, minStock: 5),
      StockItem(id: '4', name: 'Sugar (1 kg)', category: 'Groceries', quantity: 12, price: 1800, cost: 1500, minStock: 5),
      StockItem(id: '5', name: 'Bottled Water (1.5 L)', category: 'Beverages', quantity: 0, price: 1000, cost: 700, minStock: 10),
      StockItem(id: '6', name: 'Fresh Milk (500 ml)', category: 'Beverages', quantity: 8, price: 600, cost: 450, minStock: 6),
      StockItem(id: '7', name: 'Laundry Detergent', category: 'Household', quantity: 6, price: 2500, cost: 2000, minStock: 4),
      StockItem(id: '8', name: 'Exercise Book', category: 'Stationery', quantity: 40, price: 400, cost: 250, minStock: 10),
      StockItem(id: '9', name: 'Maize Flour (2 kg)', category: 'Groceries', quantity: 4, price: 2800, cost: 2300, minStock: 5),
    ]);

    // Sample sales for the last 6 days so the chart has something to show.
    final pattern = [12000.0, 8500.0, 15500.0, 9800.0, 18200.0, 11000.0];
    final now = DateTime.now();
    for (int i = 0; i < pattern.length; i++) {
      final d = now.subtract(Duration(days: 6 - i));
      history.add(StockTx(
        id: newId(),
        type: TxType.sale,
        itemName: 'Mixed items (sample)',
        qty: 4 + i,
        amount: pattern[i],
        profit: pattern[i] * 0.22,
        date: DateTime(d.year, d.month, d.day, 15, 30),
      ));
    }
    history.sort((a, b) => b.date.compareTo(a.date));
  }

  String newId() => (_idCounter++).toString();

  // ----- Stats -----
  double get totalValue => items.fold(0.0, (s, i) => s + i.price * i.quantity);
  double get totalCost => items.fold(0.0, (s, i) => s + i.cost * i.quantity);
  List<StockItem> get lowStock =>
      items.where((i) => i.quantity > 0 && i.quantity <= i.minStock).toList();
  List<StockItem> get outOfStock => items.where((i) => i.quantity == 0).toList();

  Iterable<StockTx> get sales => history.where((t) => t.type == TxType.sale);
  double get totalRevenue => sales.fold(0.0, (s, t) => s + t.amount);
  double get totalProfit => sales.fold(0.0, (s, t) => s + t.profit);
  int get unitsSold => sales.fold(0, (s, t) => s + t.qty);

  double salesOn(DateTime day) => sales
      .where((t) => sameDay(t.date, day))
      .fold(0.0, (s, t) => s + t.amount);

  double categoryValue(String c) => items
      .where((i) => i.category == c)
      .fold(0.0, (s, i) => s + i.price * i.quantity);

  // ----- Filters -----
  void setStatusFilter(StatusFilter f) {
    statusFilter = f;
    notifyListeners();
  }

  // ----- Inventory actions -----
  void _log(TxType type, String name, int qty, double amount, double profit) {
    history.insert(
      0,
      StockTx(
        id: newId(),
        type: type,
        itemName: name,
        qty: qty,
        amount: amount,
        profit: profit,
        date: DateTime.now(),
      ),
    );
  }

  void addItem(StockItem item) {
    items.insert(0, item);
    _log(TxType.added, item.name, item.quantity, 0, 0);
    notifyListeners();
  }

  void updateItem() => notifyListeners();

  int removeItem(StockItem item) {
    final idx = items.indexOf(item);
    items.remove(item);
    cart.remove(item.id);
    _log(TxType.removed, item.name, item.quantity, 0, 0);
    notifyListeners();
    return idx;
  }

  void restoreItem(StockItem item, int idx) {
    final pos = idx > items.length ? items.length : idx;
    items.insert(pos, item);
    final k = history
        .indexWhere((t) => t.type == TxType.removed && t.itemName == item.name);
    if (k >= 0) history.removeAt(k);
    notifyListeners();
  }

  void adjust(StockItem item, int delta) {
    final newQty = item.quantity + delta;
    if (newQty < 0) return;
    item.quantity = newQty;
    if (delta > 0) {
      _log(TxType.restock, item.name, delta, 0, 0);
    } else {
      _log(TxType.adjusted, item.name, -delta, 0, 0);
    }
    final inCart = cart[item.id];
    if (inCart != null && inCart > item.quantity) {
      if (item.quantity == 0) {
        cart.remove(item.id);
      } else {
        cart[item.id] = item.quantity;
      }
    }
    notifyListeners();
  }

  // ----- Cart / sales -----
  int inCart(StockItem i) => cart[i.id] ?? 0;

  void addToCart(StockItem i) {
    if (inCart(i) < i.quantity) {
      cart[i.id] = inCart(i) + 1;
      notifyListeners();
    }
  }

  void removeFromCart(StockItem i) {
    final c = inCart(i);
    if (c <= 1) {
      cart.remove(i.id);
    } else {
      cart[i.id] = c - 1;
    }
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  List<StockItem> get cartItems => items.where((i) => inCart(i) > 0).toList();
  double get cartTotal => items.fold(0.0, (s, i) => s + i.price * inCart(i));
  double get cartProfit =>
      items.fold(0.0, (s, i) => s + (i.price - i.cost) * inCart(i));

  double checkout() {
    final total = cartTotal;
    for (final i in cartItems) {
      final q = inCart(i);
      i.quantity -= q;
      _log(TxType.sale, i.name, q, i.price * q, (i.price - i.cost) * q);
    }
    cart.clear();
    notifyListeners();
    return total;
  }
}

final store = StockStore();

// ─────────────────────────────────────────────────────────────
//  App
// ─────────────────────────────────────────────────────────────

class StockManagerApp extends StatelessWidget {
  const StockManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00796B);
    return MaterialApp(
      title: 'Stock Manager',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Inventory', 'Sell', 'History'];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(onNavigate: (i) => setState(() => _index = i)),
      const InventoryPage(),
      const SellPage(),
      const HistoryPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index], style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_index == 2)
            ListenableBuilder(
              listenable: store,
              builder: (context, _) => store.cartCount == 0
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      onPressed: store.clearCart,
                      icon: const Icon(Icons.delete_sweep_rounded),
                      label: const Text('Clear cart'),
                    ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: () => showProductForm(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add product'),
            )
          : null,
      bottomNavigationBar: ListenableBuilder(
        listenable: store,
        builder: (context, _) => NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: store.lowStock.length + store.outOfStock.length > 0,
                label: Text('${store.lowStock.length + store.outOfStock.length}'),
                child: const Icon(Icons.inventory_2_outlined),
              ),
              selectedIcon: const Icon(Icons.inventory_2_rounded),
              label: 'Inventory',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: store.cartCount > 0,
                label: Text('${store.cartCount}'),
                child: const Icon(Icons.point_of_sale_outlined),
              ),
              selectedIcon: const Icon(Icons.point_of_sale_rounded),
              label: 'Sell',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Reusable widgets
// ─────────────────────────────────────────────────────────────

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, this.onMinus, this.onPlus});

  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 30,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Text('$value',
                    key: ValueKey(value),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            onPressed: onPlus,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx});

  final StockTx tx;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String title;
    String trailing;

    switch (tx.type) {
      case TxType.sale:
        icon = Icons.shopping_cart_checkout_rounded;
        color = Colors.green.shade600;
        title = 'Sold ${tx.qty} × ${tx.itemName}';
        trailing = '+${money(tx.amount)}';
        break;
      case TxType.restock:
        icon = Icons.add_box_rounded;
        color = Colors.blue.shade600;
        title = 'Restocked ${tx.qty} × ${tx.itemName}';
        trailing = '+${tx.qty} units';
        break;
      case TxType.adjusted:
        icon = Icons.remove_circle_rounded;
        color = Colors.amber.shade800;
        title = 'Removed ${tx.qty} × ${tx.itemName}';
        trailing = '-${tx.qty} units';
        break;
      case TxType.added:
        icon = Icons.fiber_new_rounded;
        color = Colors.teal.shade600;
        title = 'New product: ${tx.itemName}';
        trailing = '${tx.qty} units';
        break;
      case TxType.removed:
        icon = Icons.delete_rounded;
        color = Colors.red.shade600;
        title = 'Deleted: ${tx.itemName}';
        trailing = '';
        break;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(timeLabel(tx.date)),
      trailing: Text(trailing,
          style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Dashboard
// ─────────────────────────────────────────────────────────────

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final low = store.lowStock;
        final out = store.outOfStock;
        final attention = [...out, ...low].take(5).toList();
        final today = store.salesOn(DateTime.now());

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total stock value',
                      style: TextStyle(color: cs.onPrimary.withOpacity(0.8))),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: store.totalValue),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Text(
                      money(v),
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Potential profit: ${money(store.totalValue - store.totalCost)}',
                      style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onNavigate(2),
                    icon: const Icon(Icons.point_of_sale_rounded),
                    label: const Text('New sale'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showProductForm(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add product'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stat tiles
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.category_rounded,
                    label: 'Products',
                    value: '${store.items.length}',
                    color: Colors.teal,
                    onTap: () {
                      store.setStatusFilter(StatusFilter.all);
                      onNavigate(1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.payments_rounded,
                    label: "Today's sales",
                    value: money(today),
                    color: Colors.green,
                    onTap: () => onNavigate(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.warning_amber_rounded,
                    label: 'Low stock',
                    value: '${low.length}',
                    color: Colors.amber.shade800,
                    onTap: () {
                      store.setStatusFilter(StatusFilter.low);
                      onNavigate(1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.remove_shopping_cart_rounded,
                    label: 'Out of stock',
                    value: '${out.length}',
                    color: Colors.red,
                    onTap: () {
                      store.setStatusFilter(StatusFilter.out);
                      onNavigate(1);
                    },
                  ),
                ),
              ],
            ),

            // Sales chart
            const SectionHeader('Sales · last 7 days'),
            SoftCard(child: _salesChart(context)),

            // Category breakdown
            const SectionHeader('Stock value by category'),
            SoftCard(child: _categoryBreakdown(context)),

            // Needs attention
            SectionHeader(
              'Needs attention',
              actionLabel: attention.isEmpty ? null : 'View all',
              onAction: () {
                store.setStatusFilter(StatusFilter.low);
                onNavigate(1);
              },
            ),
            if (attention.isEmpty)
              SoftCard(
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Everything is well stocked.')),
                  ],
                ),
              )
            else
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final item in attention)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor(item).withOpacity(0.15),
                          child: Icon(Icons.warning_amber_rounded,
                              color: statusColor(item), size: 20),
                        ),
                        title: Text(item.name),
                        subtitle: Text(item.quantity == 0
                            ? 'Out of stock'
                            : '${item.quantity} left · minimum ${item.minStock}'),
                        trailing: FilledButton.tonal(
                          onPressed: () => showRestockDialog(context, item),
                          child: const Text('Restock'),
                        ),
                      ),
                  ],
                ),
              ),

            // Recent activity
            SectionHeader('Recent activity',
                actionLabel: 'See all', onAction: () => onNavigate(3)),
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final tx in store.history.take(4)) TxTile(tx: tx),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _salesChart(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)),
    );
    final vals = days.map(store.salesOn).toList();
    final maxV = vals.fold<double>(1, (m, v) => v > m ? v : m);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < 7; i++)
            Expanded(
              child: Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                message: '${names[days[i].weekday - 1]}: ${money(vals[i])}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: vals[i] / maxV),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Container(
                        height: 100 * v + 4,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: i == 6 ? cs.primary : cs.primary.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(names[days[i].weekday - 1],
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryBreakdown(BuildContext context) {
    final total = store.totalValue;
    final rows = categories.where((c) => store.categoryValue(c) > 0).toList();
    if (rows.isEmpty) return const Text('No stock yet.');
    return Column(
      children: [
        for (final c in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(categoryIcon(c), size: 18, color: categoryColor(c)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c)),
                    Text(money(store.categoryValue(c)),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: total == 0 ? 0 : store.categoryValue(c) / total),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      color: categoryColor(c),
                      backgroundColor: categoryColor(c).withOpacity(0.15),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SoftCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Inventory
// ─────────────────────────────────────────────────────────────

enum SortBy { newest, name, lowest, value }

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  SortBy _sort = SortBy.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StockItem> get _visible {
    final q = _query.trim().toLowerCase();
    final list = store.items.where((i) {
      final matchesQuery = q.isEmpty ||
          i.name.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q);
      final matchesCategory = _category == null || i.category == _category;
      final matchesStatus = switch (store.statusFilter) {
        StatusFilter.all => true,
        StatusFilter.low => i.quantity > 0 && i.quantity <= i.minStock,
        StatusFilter.out => i.quantity == 0,
      };
      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();

    switch (_sort) {
      case SortBy.newest:
        break;
      case SortBy.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortBy.lowest:
        list.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case SortBy.value:
        list.sort((a, b) => (b.price * b.quantity).compareTo(a.price * a.quantity));
        break;
    }
    return list;
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: color?.withOpacity(0.2),
        onSelected: (_) => onTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = _visible;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search products…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<SortBy>(
                    icon: const Icon(Icons.sort_rounded),
                    tooltip: 'Sort',
                    initialValue: _sort,
                    onSelected: (s) => setState(() => _sort = s),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: SortBy.newest, child: Text('Newest first')),
                      PopupMenuItem(value: SortBy.name, child: Text('Name (A–Z)')),
                      PopupMenuItem(value: SortBy.lowest, child: Text('Lowest stock')),
                      PopupMenuItem(value: SortBy.value, child: Text('Highest value')),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip('All', store.statusFilter == StatusFilter.all,
                      () => store.setStatusFilter(StatusFilter.all)),
                  _chip('Low stock', store.statusFilter == StatusFilter.low,
                      () => store.setStatusFilter(StatusFilter.low),
                      color: Colors.amber.shade800),
                  _chip('Out of stock', store.statusFilter == StatusFilter.out,
                      () => store.setStatusFilter(StatusFilter.out),
                      color: Colors.red),
                  const SizedBox(height: 28, child: VerticalDivider(width: 16)),
                  for (final c in categories)
                    _chip(c, _category == c,
                        () => setState(() => _category = _category == c ? null : c),
                        color: categoryColor(c)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${items.length} of ${store.items.length} products',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No products found',
                      subtitle: 'Try a different search or clear the filters.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: items.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ProductCard(item: items[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = categoryColor(item.category);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        final idx = store.removeItem(item);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text('${item.name} deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => store.restoreItem(item, idx),
            ),
          ));
      },
      child: SoftCard(
        onTap: () => showProductForm(context, item: item),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(categoryIcon(item.category), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusBadge(label: statusLabel(item), color: statusColor(item)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(item.category,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${money(item.price)} each · Total ${money(item.price * item.quantity)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            QtyStepper(
              value: item.quantity,
              onMinus: item.quantity > 0 ? () => store.adjust(item, -1) : null,
              onPlus: () => store.adjust(item, 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Add / edit product form
// ─────────────────────────────────────────────────────────────

Future<void> showProductForm(BuildContext context, {StockItem? item}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProductForm(item: item),
  );
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.item});

  final StockItem? item;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.item?.name ?? '');
  late final TextEditingController _qty =
      TextEditingController(text: widget.item?.quantity.toString() ?? '');
  late final TextEditingController _min =
      TextEditingController(text: widget.item?.minStock.toString() ?? '5');
  late final TextEditingController _price = TextEditingController(
      text: widget.item == null ? '' : widget.item!.price.round().toString());
  late final TextEditingController _cost = TextEditingController(
      text: widget.item == null ? '' : widget.item!.cost.round().toString());
  late String _category = widget.item?.category ?? categories.first;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _min.dispose();
    _price.dispose();
    _cost.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final qty = int.parse(_qty.text);
    final min = int.parse(_min.text);
    final price = double.parse(_price.text);
    final cost = double.parse(_cost.text);

    if (widget.item == null) {
      store.addItem(StockItem(
        id: store.newId(),
        name: name,
        category: _category,
        quantity: qty,
        price: price,
        cost: cost,
        minStock: min,
      ));
    } else {
      final it = widget.item!;
      it.name = name;
      it.category = _category;
      it.quantity = qty;
      it.price = price;
      it.cost = cost;
      it.minStock = min;
      store.updateItem();
    }
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(widget.item == null ? '$name added' : '$name updated'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(editing ? 'Edit product' : 'New product',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  prefixIcon: Icon(Icons.label_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_rounded),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in categories) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _required,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _required,
                      decoration: const InputDecoration(
                        labelText: 'Low-stock alert at',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _required,
                      decoration: const InputDecoration(
                        labelText: 'Selling price (Frw)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cost,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _required,
                      decoration: const InputDecoration(
                        labelText: 'Buying cost (Frw)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(editing ? Icons.check_rounded : Icons.add_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(editing ? 'Save changes' : 'Add product'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Restock dialog
// ─────────────────────────────────────────────────────────────

Future<void> showRestockDialog(BuildContext context, StockItem item) {
  return showDialog(context: context, builder: (_) => _RestockDialog(item: item));
}

class _RestockDialog extends StatefulWidget {
  const _RestockDialog({required this.item});

  final StockItem item;

  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  int _qty = 10;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Restock ${widget.item.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Currently ${widget.item.quantity} in stock'),
          const SizedBox(height: 16),
          QtyStepper(
            value: _qty,
            onMinus: _qty > 1 ? () => setState(() => _qty--) : null,
            onPlus: () => setState(() => _qty++),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final n in [5, 10, 25, 50])
                ActionChip(
                  label: Text('+$n'),
                  onPressed: () => setState(() => _qty += n),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context);
            store.adjust(widget.item, _qty);
            Navigator.pop(context);
            messenger.showSnackBar(
              SnackBar(content: Text('Added $_qty to ${widget.item.name}')),
            );
          },
          child: Text('Add $_qty'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Sell (point of sale)
// ─────────────────────────────────────────────────────────────

class SellPage extends StatefulWidget {
  const SellPage({super.key});

  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final q = _query.trim().toLowerCase();
        final items = store.items
            .where((i) => q.isEmpty || i.name.toLowerCase().contains(q))
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Find a product to sell…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No products found',
                      subtitle: 'Try a different search.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final inCart = store.inCart(item);
                        final soldOut = item.quantity == 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Opacity(
                            opacity: soldOut ? 0.5 : 1,
                            child: SoftCard(
                              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${money(item.price)} · ${soldOut ? 'Out of stock' : '${item.quantity} available'}',
                                          style: TextStyle(
                                              fontSize: 12, color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (inCart == 0)
                                    FilledButton.tonalIcon(
                                      onPressed:
                                          soldOut ? null : () => store.addToCart(item),
                                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                                      label: const Text('Add'),
                                    )
                                  else
                                    QtyStepper(
                                      value: inCart,
                                      onMinus: () => store.removeFromCart(item),
                                      onPlus: inCart < item.quantity
                                          ? () => store.addToCart(item)
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: store.cartCount == 0
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${store.cartCount} item(s) in cart',
                                    style: TextStyle(color: cs.onPrimaryContainer)),
                                Text(money(store.cartTotal),
                                    style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    )),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => showCheckoutSheet(context),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Review & pay'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

void showCheckoutSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: store,
      builder: (ctx, _) {
        final lines = store.cartItems;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Review sale',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Your cart is empty.')),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final i in lines)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(i.name),
                            subtitle: Text(
                                '${money(i.price)} × ${store.inCart(i)} = ${money(i.price * store.inCart(i))}'),
                            trailing: QtyStepper(
                              value: store.inCart(i),
                              onMinus: () => store.removeFromCart(i),
                              onPlus: store.inCart(i) < i.quantity
                                  ? () => store.addToCart(i)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(child: Text('Total')),
                    Text(money(store.cartTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text('Estimated profit',
                          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                    ),
                    Text(money(store.cartProfit),
                        style: TextStyle(
                            color: Colors.green.shade600, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: lines.isEmpty
                        ? null
                        : () {
                            final messenger = ScaffoldMessenger.of(context);
                            final total = store.checkout();
                            Navigator.pop(sheetContext);
                            messenger.showSnackBar(SnackBar(
                              content: Text('Sale recorded: ${money(total)}'),
                            ));
                          },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Confirm sale'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  History
// ─────────────────────────────────────────────────────────────

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _filter = 0; // 0 all, 1 sales, 2 restocks, 3 other

  bool _matches(StockTx t) {
    switch (_filter) {
      case 1:
        return t.type == TxType.sale;
      case 2:
        return t.type == TxType.restock;
      case 3:
        return t.type == TxType.adjusted ||
            t.type == TxType.added ||
            t.type == TxType.removed;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final txs = store.history.where(_matches).toList();
        const labels = ['All', 'Sales', 'Restocks', 'Other'];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Revenue',
                      value: money(store.totalRevenue),
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Profit',
                      value: money(store.totalProfit),
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Units sold',
                      value: '${store.unitsSold}',
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (int i = 0; i < labels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(labels[i]),
                        selected: _filter == i,
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: txs.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Nothing here yet',
                      subtitle: 'Sales and stock changes will show up here.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: txs.length,
                      itemBuilder: (_, i) => TxTile(tx: txs[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
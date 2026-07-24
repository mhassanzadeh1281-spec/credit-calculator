import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ماشین حساب اعتباری',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        direction: TextDirection.rtl,
      ),
      home: const CreditCalculatorPage(),
    );
  }
}

class CreditCalculatorPage extends StatefulWidget {
  const CreditCalculatorPage({super.key});

  @override
  State<CreditCalculatorPage> createState() => _CreditCalculatorPageState();
}

class _CreditCalculatorPageState extends State<CreditCalculatorPage> {
  final Map<String, Map<String, dynamic>> _durationData = {
    'حداکثر ۶ ماه': {'avgPeriod': '۶ ماه', 'currentRatio': 2.5, 'shortRatio': 3.0},
    'حداکثر یک سال': {'avgPeriod': '۶ ماه', 'currentRatio': 3.0, 'shortRatio': 2.5},
    '۱ تا ۲ سال': {'avgPeriod': '۹ ماه', 'currentRatio': 2.0, 'shortRatio': 1.8},
    '۲ تا ۳ سال': {'avgPeriod': '۱۲ ماه', 'currentRatio': 1.25, 'shortRatio': 1.5},
  };

  final Map<String, double> _creditRatingData = {
    'A': 1.8, 'B': 1.0, 'C': 0.9, 'D': 0.8, 'E': 0.5, 'فاقد رتبه اعتباری': 0.8,
  };

  String _selectedDuration = 'حداکثر ۶ ماه';
  String _selectedRating = 'A';
  final TextEditingController _currentAvgController = TextEditingController(text: '0');
  final TextEditingController _shortAvgController = TextEditingController(text: '0');
  final TextEditingController _requestAmountController = TextEditingController(text: '0');

  double _maxFacility = 0;
  double _currentCapacity = 0;
  double _shortCapacity = 0;
  double _totalCapacity = 0;
  double _progress = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      final durationData = _durationData[_selectedDuration]!;
      final ratingFactor = _creditRatingData[_selectedRating]!;
      final currentAvg = double.tryParse(_currentAvgController.text) ?? 0;
      final shortAvg = double.tryParse(_shortAvgController.text) ?? 0;
      final requestAmount = double.tryParse(_requestAmountController.text) ?? 0;

      _currentCapacity = currentAvg * durationData['currentRatio'];
      _shortCapacity = shortAvg * durationData['shortRatio'];
      _totalCapacity = _currentCapacity + _shortCapacity;
      _maxFacility = _totalCapacity * ratingFactor;

      if (requestAmount == 0) {
        _status = 'مبلغ تسهیلات درخواستی وارد نشده است';
        _progress = 0;
      } else if (requestAmount <= _maxFacility) {
        _status = '✅ مبلغ درخواستی در سقف اعتبار قرار دارد';
        _progress = requestAmount / _maxFacility;
      } else {
        _status = '❌ مبلغ درخواستی بیشتر از سقف اعتبار محاسبه‌شده است';
        _progress = 1;
      }
    });
  }

  List<Map<String, dynamic>> _calculateRequiredAverages() {
    final requestAmount = double.tryParse(_requestAmountController.text) ?? 0;
    final ratingFactor = _creditRatingData[_selectedRating]!;
    List<Map<String, dynamic>> results = [];
    if (requestAmount == 0) return results;

    _durationData.forEach((duration, data) {
      final currentRequired = requestAmount / (data['currentRatio'] * ratingFactor);
      final shortRequired = requestAmount / (data['shortRatio'] * ratingFactor);
      results.add({
        'duration': duration,
        'avgPeriod': data['avgPeriod'],
        'currentRequired': currentRequired,
        'shortRequired': shortRequired,
        'minRequired': currentRequired < shortRequired ? currentRequired : shortRequired,
        'bestAccount': currentRequired < shortRequired ? 'حساب جاری' : 'حساب کوتاه‌مدت',
      });
    });
    return results;
  }

  void _shareResult() {
    final requestAmount = double.tryParse(_requestAmountController.text) ?? 0;
    final diff = _maxFacility - requestAmount;
    final diffText = diff >= 0
        ? 'مبلغ قابل استفاده باقی‌مانده: ${NumberFormat('#,##0').format(diff)}'
        : 'مبلغ مازاد بر سقف اعتبار: ${NumberFormat('#,##0').format(-diff)}';

    final text = '''
📊 نتیجه محاسبه اعتبار
━━━━━━━━━━━━━━━━━━━━━
مدت تسهیلات: $_selectedDuration
رتبه اعتباری: $_selectedRating
حداکثر تسهیلات قابل اعطا: ${NumberFormat('#,##0').format(_maxFacility)}
مبلغ درخواستی: ${NumberFormat('#,##0').format(requestAmount)}
وضعیت: $_status
$diffText
    ''';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final requiredAverages = _calculateRequiredAverages();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ماشین حساب اعتباری'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('📝 اطلاعات ورودی', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      value: _selectedDuration,
                      decoration: const InputDecoration(labelText: 'مدت تسهیلات', border: OutlineInputBorder()),
                      items: _durationData.keys.map((key) => DropdownMenuItem(value: key, child: Text(key))).toList(),
                      onChanged: (value) { setState(() { _selectedDuration = value!; _calculate(); }); },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedRating,
                      decoration: const InputDecoration(labelText: 'رتبه اعتباری', border: OutlineInputBorder()),
                      items: _creditRatingData.keys.map((key) => DropdownMenuItem(value: key, child: Text(key))).toList(),
                      onChanged: (value) { setState(() { _selectedRating = value!; _calculate(); }); },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _currentAvgController,
                      decoration: const InputDecoration(labelText: 'میانگین حساب جاری', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _calculate(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _shortAvgController,
                      decoration: const InputDecoration(labelText: 'میانگین حساب کوتاه‌مدت', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _calculate(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _requestAmountController,
                      decoration: const InputDecoration(labelText: 'مبلغ تسهیلات درخواستی', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _calculate(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📊 نتیجه محاسبه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _buildResultRow('ظرفیت حساب جاری', _currentCapacity),
                    _buildResultRow('ظرفیت حساب کوتاه‌مدت', _shortCapacity),
                    _buildResultRow('مجموع ظرفیت', _totalCapacity),
                    _buildResultRow('حداکثر تسهیلات قابل اعطا', _maxFacility, isBold: true),
                    if (_progress > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progress > 1 ? 1 : _progress,
                        backgroundColor: Colors.grey.shade300,
                        color: _progress <= 0.5 ? Colors.green : _progress <= 0.9 ? Colors.orange : Colors.red,
                        minHeight: 12,
                      ),
                      Text('${(_progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _status.contains('✅') ? Colors.green.shade100 : _status.contains('❌') ? Colors.red.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_status, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _shareResult,
                      icon: const Icon(Icons.share),
                      label: const Text('اشتراک‌گذاری نتیجه'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            if (requiredAverages.isNotEmpty)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📋 میانگین لازم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('مدت تسهیلات')),
                            DataColumn(label: Text('مدت میانگین')),
                            DataColumn(label: Text('جاری لازم')),
                            DataColumn(label: Text('کوتاه‌مدت لازم')),
                            DataColumn(label: Text('کمترین')),
                            DataColumn(label: Text('پیشنهاد')),
                          ],
                          rows: requiredAverages.map((item) {
                            return DataRow(cells: [
                              DataCell(Text(item['duration'])),
                              DataCell(Text(item['avgPeriod'])),
                              DataCell(Text(NumberFormat('#,##0').format(item['currentRequired']))),
                              DataCell(Text(NumberFormat('#,##0').format(item['shortRequired']))),
                              DataCell(Text(NumberFormat('#,##0').format(item['minRequired']), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: item['bestAccount'] == 'حساب جاری' ? Colors.blue.shade100 : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(item['bestAccount'], style: const TextStyle(fontSize: 12)),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _currentAvgController.text = '0';
            _shortAvgController.text = '0';
            _requestAmountController.text = '0';
            _calculate();
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildResultRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(NumberFormat('#,##0').format(value), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14)),
        ],
      ),
    );
  }
}
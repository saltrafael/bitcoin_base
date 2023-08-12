import 'dart:typed_data';
import 'package:bitcoin/src/models/network.dart';
import 'package:bitcoin/src/bitcoin/address/segwit_address.dart';
import 'package:bitcoin/src/bitcoin/constant/constant.dart';
import 'package:bitcoin/src/bitcoin/script/input.dart';
import 'package:bitcoin/src/bitcoin/script/output.dart';
import 'package:bitcoin/src/bitcoin/script/script.dart';
import 'package:bitcoin/src/bitcoin/script/transaction.dart';
import 'package:bitcoin/src/bitcoin/script/witness.dart';
import 'package:bitcoin/src/crypto/ec/ec_public.dart';
import '../utxo.dart';

(String, String) spendp2wkh({
  required P2wpkhAddress receiver,
  required ECPublic senderPub,
  required NetworkInfo networkType,
  required String Function(Uint8List, {int sigHash}) sign,
  required List<UTXO> utxo,
  BigInt? value,
  required BigInt estimateFee,
  int? trSize,
  int sighash = SIGHASH_ALL,
  P2wpkhAddress? changeAddress,
}) {
  int someBytes = 100 + (utxo.length * 100);

  final fee = BigInt.from((trSize ?? someBytes)) * estimateFee;
  final BigInt sumUtxo = utxo.fold(
      BigInt.zero, (previousValue, element) => previousValue + element.value);
  BigInt mustSend = value ?? sumUtxo;
  if (value == null) {
    mustSend = sumUtxo - fee;
  } else {
    BigInt currentValue = value + fee;
    if (trSize != null && sumUtxo < currentValue) {
      throw Exception(
          "need money balance $sumUtxo value + fee = $currentValue");
    }
  }
  if (mustSend.isNegative) {
    throw Exception(
        "your balance must >= transaction ${value ?? sumUtxo} + $fee");
  }
  BigInt needChangeTx = sumUtxo - (mustSend + fee);
  final txin = utxo.map((e) => TxInput(txId: e.txId, txIndex: e.vout)).toList();
  final List<TxWitnessInput> w = [];
  final List<TxOutput> txOut = [
    TxOutput(
        amount: mustSend,
        scriptPubKey: Script(script: receiver.toScriptPubKey()))
  ];
  if (needChangeTx > BigInt.zero) {
    txOut.add(TxOutput(
        amount: needChangeTx,
        scriptPubKey: Script(
            script: changeAddress?.toScriptPubKey() ??
                senderPub.toSegwitAddress().toScriptPubKey())));
  }
  final tx = BtcTransaction(inputs: txin, outputs: txOut, hasSegwit: true);
  for (int i = 0; i < txin.length; i++) {
    final txDigit = tx.getTransactionSegwitDigit(
        txInIndex: i,
        script: Script(script: senderPub.toAddress().toScriptPubKey()),
        sighash: sighash,
        amount: utxo[i].value);
    final signedTx = sign(txDigit, sigHash: sighash);
    w.add(TxWitnessInput(stack: [signedTx, senderPub.toHex()]));
  }

  tx.witnesses.addAll(w);
  if (trSize == null) {
    return spendp2wkh(
        estimateFee: estimateFee,
        networkType: networkType,
        receiver: receiver,
        senderPub: senderPub,
        sign: sign,
        utxo: utxo,
        value: value,
        sighash: sighash,
        trSize: tx.getVSize());
  }
  return (tx.serialize(), tx.txId());
}

// spend from 8 different address type to 10 different output
// ignore_for_file: unused_local_variable

import 'package:bitcoin_base/src/bitcoin/address/core.dart';
import 'package:bitcoin_base/src/crypto/crypto.dart';
import 'package:bitcoin_base/src/models/network.dart';
import 'package:bitcoin_base/src/provider/api_provider.dart';
import 'package:bitcoin_base/src/provider/multisig_script.dart';
import 'package:bitcoin_base/src/provider/transaction_builder.dart';
import 'package:bitcoin_base/src/provider/utxo_details.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

void main() async {
  // select network
  const NetworkInfo network = NetworkInfo.TESTNET;

  // select api for read accounts UTXOs and send transaction
  // Mempool or BlockCypher
  final api = ApiProvider.fromMempl(network);

  const mnemonic =
      "spy often critic spawn produce volcano depart fire theory fog turn retire";

  final masterWallet = BIP32HWallet.fromMnemonic(mnemonic);

  // i generate 4 HD wallet for this test and now i have access to private and pulic key of each wallet
  final sp1 = BIP32HWallet.drivePath(masterWallet, "m/44'/0'/0'/0/0/1");
  final sp2 = BIP32HWallet.drivePath(masterWallet, "m/44'/0'/0'/0/0/2");
  final sp3 = BIP32HWallet.drivePath(masterWallet, "m/44'/0'/0'/0/0/3");
  final sp4 = BIP32HWallet.drivePath(masterWallet, "m/44'/0'/0'/0/0/4");
  final sp5 = BIP32HWallet.drivePath(masterWallet, "m/44'/0'/0'/0/0/4");
  final sp6 = BIP32HWallet.drivePath(masterWallet, "m/44'/0'/0'/0/0/4");
  // access to private key `ECPrivate`
  final private1 = ECPrivate.fromBytes(sp1.privateKey);
  final private2 = ECPrivate.fromBytes(sp2.privateKey);
  final private3 = ECPrivate.fromBytes(sp3.privateKey);
  final private4 = ECPrivate.fromBytes(sp4.privateKey);

  final private5 = ECPrivate.fromBytes(sp5.privateKey);
  final private6 = ECPrivate.fromBytes(sp6.privateKey);
  // access to public key `ECPublic`
  final public1 = private1.getPublic();
  final public2 = private2.getPublic();
  final public3 = private3.getPublic();
  final public4 = private4.getPublic();
  final public5 = private5.getPublic();
  final public6 = private6.getPublic();

  final signer1 = MultiSignatureSigner(publicKey: public1.toHex(), weight: 2);

  final signer2 = MultiSignatureSigner(publicKey: public2.toHex(), weight: 2);

  final signer3 = MultiSignatureSigner(publicKey: public3.toHex(), weight: 1);

  final signer4 = MultiSignatureSigner(publicKey: public4.toHex(), weight: 1);

  final MultiSignatureAddress multiSignatureAddress = MultiSignatureAddress(
      threshold: 4,
      signers: [signer1, signer2, signer3, signer4],
      addressType: AddressType.p2wsh);
  // P2WSH Multisig 4-6
  // tb1qxt3c7849m0m6cv3z3s35c3zvdna3my3yz0r609qd9g0dcyyk580sgyldhe

  final p2wshMultiSigAddress = multiSignatureAddress.address.toAddress(network);

  // p2sh(p2wsh) multisig
  final signerP2sh1 =
      MultiSignatureSigner(publicKey: public5.toHex(), weight: 1);

  final signerP2sh2 =
      MultiSignatureSigner(publicKey: public6.toHex(), weight: 1);

  final signerP2sh3 =
      MultiSignatureSigner(publicKey: public1.toHex(), weight: 1);

  final MultiSignatureAddress p2shMultiSignature = MultiSignatureAddress(
      threshold: 2,
      signers: [signerP2sh1, signerP2sh2, signerP2sh3],
      addressType: AddressType.p2wshInP2sh);
  // P2SH(P2WSH) miltisig 2-3
  // 2N8co8bth9CNKtnWGfHW6HuUNgnNPNdpsMj
  final p2shMultisigAddress = p2shMultiSignature.address.toAddress(network);

  // P2TR
  final exampleAddr2 = public2.toTaprootAddress();
  // P2KH
  final exampleAddr4 = public3.toAddress();
  // Spending List
  // i use some different address type for this
  // now i want to spending from 8 address in one transaction
  // we need publicKeys and address
  final spenders = [
    UtxoOwnerDetails(
        multiSigAddress: multiSignatureAddress,
        address: multiSignatureAddress.address),
    UtxoOwnerDetails(
        multiSigAddress: p2shMultiSignature,
        address: p2shMultiSignature.address),
    UtxoOwnerDetails(publicKey: public2.toHex(), address: exampleAddr2),
  ];

  // i need now to read spenders account UTXOS
  final List<UtxoWithOwner> utxos = [];

  // i add some method for provider to read utxos from mempol or blockCypher
  // looping address to read Utxos
  for (final spender in spenders) {
    try {
      // read each address utxo from mempool
      final spenderUtxos = await api.getAccountUtxo(spender);
      // check if account have any utxo for spending (balance)

      if (!spenderUtxos.canSpend()) {
        // address does not have any satoshi for spending:
        continue;
      }

      utxos.addAll(spenderUtxos);
    } on ApiProviderException {
      // something bad happen when reading Utxos:
      return;
    }
  }
  // Well, now we calculate how much we can spend
  final sumOfUtxo = utxos.sumOfUtxosValue();

  // 1,479,604 sum of all utxos

  final hasSatoshi = sumOfUtxo != BigInt.zero;

  if (!hasSatoshi) {
    // Are you kidding? We don't have btc to spend
    return;
  }
  String? memo = "https://github.com/mrtnetwork";

  // fee calculation
  // To calculate the transaction fee, we need to have the transaction size

  // To achieve this, we create a dummy transaction with the desired inputs
  // and outputs to determine the transaction size accurately.
  // The correctness of UTXOs, the type of address for outputs,
  // and data (memo) are crucial. If any of these aspects differ from the original transaction,
  // the transaction size may vary. We consider the maximum amount for each transaction in the fake transaction.
  // In any case, the size of each input amount is 8 bytes
  // I have created a method for accomplishing this.
  int size = BitcoinTransactionBuilder.estimateTransactionSize(
      utxos: utxos,
      outputs: [
        p2shMultiSignature.address,
        multiSignatureAddress.address,
        exampleAddr2,
        exampleAddr4
      ],
      network: network,
      memo: memo,
      enableRBF: true);
  // transaction size: 565 byte

  // Ok now we have the transaction size, let's get the estimated cost
  // Use the BlockCypher API to obtain the network cost because Mempool doesn't provide us
  // with the actual transaction cost for the test network.
  // That's my perspective, of course.
  final blockCypher = ApiProvider.fromBlocCypher(network, client: api.client);

  final feeRate = await blockCypher.getNetworkFeeRate();
  // fee rate inKB
  // feeRate.medium: 32279 P/KB
  // feeRate.high: 43009  P/KB
  // feeRate.low: 22594 P/KB

  // Well now we have the transaction fee and we can create the outputs based on this
  // 565 byte / 1024 * (feeRate / 32279 )  = 17810

  final fee = feeRate.getEstimate(size, feeRate: feeRate.medium);
  // fee = 17,810

  // We consider 17,810 satoshi for the cost

  // now we have 1,461,794(1,479,604/sumOfUtxo - 17,810/fee) satoshi for spending let do it
  // we create 4 different output with  different address type like (p2sh, p2wsh, etc.)
  // We consider the spendable amount for 4 outputs and divide by 4, each output 365448.5,
  // 365448 for two addresses and 365449 for two addresses because of decimal
  final output1 = BitcoinOutputDetails(
      address: p2shMultiSignature.address, value: BigInt.from(365449));
  final output2 = BitcoinOutputDetails(
      address: multiSignatureAddress.address, value: BigInt.from(365449));
  final output3 =
      BitcoinOutputDetails(address: exampleAddr2, value: BigInt.from(365448));
  final output4 =
      BitcoinOutputDetails(address: exampleAddr4, value: BigInt.from(365448));

  // Well, now it is clear to whom we are going to pay the amount
  // Now let's create the transaction
  final transactionBuilder = BitcoinTransactionBuilder(
    // Now, we provide the UTXOs we want to spend.
    utxos: utxos,
    // We select transaction outputs
    outPuts: [output1, output2, output3, output4],
    /*
			Transaction fee
			Ensure that you have accurately calculated the amounts.
			If the sum of the outputs, including the transaction fee,
			does not match the total amount of UTXOs,
			it will result in an error. Please double-check your calculations.
		*/
    fee: fee,
    // network, testnet, mainnet
    network: network,
    // If you wish to record information in your transaction on the blockchain network,
    // please enter it here (memo). Keep in mind that the transaction fee will increase
    // relative to the amount of information included
    memo: memo,
    /*
			RBF, or Replace-By-Fee, is a feature in Bitcoin that allows you to increase the fee of an unconfirmed
			transaction that you've broadcasted to the network.
			This feature is useful when you want to speed up a
			transaction that is taking longer than expected to get confirmed due to low transaction fees.
		*/
    enableRBF: true,
  );

  // now we use BuildTransaction to complete them
  // I considered a method parameter for this, to sign the transaction

  // I've added a method for signing the transaction as a parameter.
  // This method sends you the public key for each UTXO,
  // allowing you to sign the desired input with the associated private key
  final transaction =
      transactionBuilder.buildTransaction((trDigest, utxo, publicKey) {
    late ECPrivate key;

    // ok we have the public key of the current UTXO and we use some conditions to find private  key and sign transaction
    String currentPublicKey = publicKey;

    // if is multi-sig and we dont have access to some private key of address we return empty string
    // Note that you must have access to keys with the required signature(threshhold); otherwise,
    // you will receive an error.
    if (utxo.isMultiSig()) {
      // check we have private keys of this sigerns or not
      // return ""
    }
    if (currentPublicKey == public3.toHex()) {
      key = private3;
    } else if (currentPublicKey == public2.toHex()) {
      key = private2;
    } else if (currentPublicKey == public1.toHex()) {
      key = private1;
    } else if (currentPublicKey == public4.toHex()) {
      key = private4;
    } else if (currentPublicKey == public5.toHex()) {
      key = private5;
    } else if (currentPublicKey == public6.toHex()) {
      key = private6;
    } else {
      throw Exception("Cannot find private key");
    }

    // Ok, now we have the private key, we need to check which method to use for signing
    // We check whether the UTX corresponds to the P2TR address or not.
    if (utxo.utxo.isP2tr()) {
      // yes is p2tr utxo and now we use SignTaprootTransaction(Schnorr sign)
      // for now this transaction builder support only tweak transaction
      // If you want to spend a Taproot script-path spending, you must create your own transaction builder.
      return key.signTapRoot(trDigest);
    } else {
      // is seqwit(v0) or lagacy address we use  SingInput (ECDSA)
      return key.signInput(trDigest);
    }
  });

  // ok everything is fine and we need a transaction output for broadcasting
  // We use the Serialize method to receive the transaction output
  final digest = transaction.serialize();

  // we check if transaction is segwit or not
  // When one of the input UTXO addresses is SegWit, the transaction is considered SegWit.
  final isSegwitTr = transactionBuilder.hasSegwit();

  // transaction id
  final transactionId = transaction.txId();

  // transaction size
  int transactionSize;

  if (isSegwitTr) {
    transactionSize = transaction.getVSize();
  } else {
    transactionSize = transaction.getSize();
  }
  // real transaction size: 565
  // fake transaction size: 565
  // In all cases this should be the same

  try {
    // now we send transaction to network
    final txId = await blockCypher.sendRawTransaction(digest);
    // Yes, we did :)  19317835855d50a822257247ee8ff2bab0e4c7d3a9000bd4006190d52975517e
    // Now we check Mempol for what happened https://mempool.space/testnet/tx/19317835855d50a822257247ee8ff2bab0e4c7d3a9000bd4006190d52975517e
  } on ApiProviderException {
    // Something went wrong when sending the transaction
  }
}

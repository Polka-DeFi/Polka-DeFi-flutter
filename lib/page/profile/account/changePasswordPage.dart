import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:polka_wallet/common/components/roundedButton.dart';
import 'package:polka_wallet/page/profile/account/accountManagePage.dart';
import 'package:polka_wallet/service/substrateApi/api.dart';
import 'package:polka_wallet/store/account/account.dart';
import 'package:polka_wallet/utils/format.dart';
import 'package:polka_wallet/utils/i18n/index.dart';

class ChangePasswordPage extends StatefulWidget {
  ChangePasswordPage(this.store);

  static final String route = '/profile/password';
  final AccountStore store;

  @override
  _ChangePassword createState() => _ChangePassword(store);
}

class _ChangePassword extends State<ChangePasswordPage> {
  _ChangePassword(this.store);

  final Api api = webApi;
  final AccountStore store;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passOldCtrl = new TextEditingController();
  final TextEditingController _passCtrl = new TextEditingController();
  final TextEditingController _pass2Ctrl = new TextEditingController();

  bool _submitting = false;

  bool _supportBiometric = false; // if device support biometric
  bool _enableBiometric = true; // if the biometric usage checkbox checked

  Future<void> _onSave() async {
    if (_formKey.currentState.validate()) {
      setState(() {
        _submitting = true;
      });
      var dic = I18n.of(context).profile;
      final String passOld = _passOldCtrl.text.trim();
      final String passNew = _passCtrl.text.trim();
      // check password
      final passChecked = await webApi.account
          .checkAccountPassword(store.currentAccount, passOld);
      if (passChecked == null) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: Text(dic['pass.error']),
              content: Text(dic['pass.error.txt']),
              actions: <Widget>[
                CupertinoButton(
                  child: Text(I18n.of(context).home['ok']),
                  onPressed: () {
                    _passOldCtrl.clear();
                    setState(() {
                      _submitting = false;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        final Map acc = await api.evalJavascript(
            'account.changePassword("${store.currentAccount.pubKey}", "$passOld", "$passNew")');
        // use local name, not webApi returned name
        acc['meta']['name'] = store.currentAccount.name;
        store.updateAccount(acc);
        // update encrypted seed after password updated
        store.updateSeed(store.currentAccountPubKey, passOld, passNew);

        // update biometric storage after password updated
        if (_enableBiometric) {
          try {
            final storage = await webApi.account
                .getBiometricPassStoreFile(context, store.currentAccountPubKey);
            await storage.write(passNew);
            webApi.account.setBiometricEnabled(store.currentAccountPubKey);
          } catch (err) {
            // user may cancel the biometric auth. then we set biometric disabled
            webApi.account.setBiometricDisabled(store.currentAccountPubKey);
          }
        } else {
          webApi.account.setBiometricDisabled(store.currentAccountPubKey);
        }

        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: Text(dic['pass.success']),
              content: Text(dic['pass.success.txt']),
              actions: <Widget>[
                CupertinoButton(
                  child: Text(I18n.of(context).home['ok']),
                  onPressed: () => Navigator.popUntil(
                      context, ModalRoute.withName(AccountManagePage.route)),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _checkBiometricSupport() async {
    final canAuth = await BiometricStorage().canAuthenticate();

    setState(() {
      _supportBiometric = canAuth == CanAuthenticateResponse.success;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricSupport();
    });
  }

  @override
  Widget build(BuildContext context) {
    var dic = I18n.of(context).profile;
    var accDic = I18n.of(context).account;
    return Scaffold(
      appBar: AppBar(
        title: Text(dic['pass.change']),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: <Widget>[
                    TextFormField(
                      decoration: InputDecoration(
                        icon: Icon(Icons.lock),
                        hintText: dic['pass.old'],
                        labelText: dic['pass.old'],
                        suffixIcon: IconButton(
                          iconSize: 18,
                          icon: Icon(
                            CupertinoIcons.clear_thick_circled,
                            color: Theme.of(context).unselectedWidgetColor,
                          ),
                          onPressed: () {
                            WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _passOldCtrl.clear());
                          },
                        ),
                      ),
                      controller: _passOldCtrl,
                      validator: (v) {
                        // TODO: fix me: disable validator for polkawallet-RN exported keystore importing
                        return null;
                        return Fmt.checkPassword(v.trim())
                            ? null
                            : accDic['create.password.error'];
                      },
                      obscureText: true,
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                        icon: Icon(Icons.lock),
                        hintText: dic['pass.new'],
                        labelText: dic['pass.new'],
                      ),
                      controller: _passCtrl,
                      validator: (v) {
                        return Fmt.checkPassword(v.trim())
                            ? null
                            : accDic['create.password.error'];
                      },
                      obscureText: true,
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                        icon: Icon(Icons.lock),
                        hintText: dic['pass.new2'],
                        labelText: dic['pass.new2'],
                      ),
                      controller: _pass2Ctrl,
                      validator: (v) {
                        return v.trim() != _passCtrl.text
                            ? accDic['create.password2.error']
                            : null;
                      },
                      obscureText: true,
                    ),
                    _supportBiometric
                        ? Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _enableBiometric,
                                    onChanged: (v) {
                                      setState(() {
                                        _enableBiometric = v;
                                      });
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(left: 16),
                                  child: Text(I18n.of(context)
                                      .home['unlock.bio.enable']),
                                )
                              ],
                            ),
                          )
                        : Container(),
                  ],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.all(16),
              child: RoundedButton(
                text: dic['contact.save'],
                icon: _submitting ? CupertinoActivityIndicator() : null,
                onPressed: _submitting ? null : _onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

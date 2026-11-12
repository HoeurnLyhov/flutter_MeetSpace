import 'package:flutter/material.dart';
import '../core/copy.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';

class SignInPage extends StatefulWidget {
  final Session session;
  const SignInPage({super.key, required this.session});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false, obscure = true;
  Object? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.signIn(email.text, password.text);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: busy
                            ? null
                            : () => widget.session.setLocale(
                                widget.session.locale == 'en' ? 'km' : 'en',
                              ),
                        child: Text(context.t('switchLanguage')),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Civic.navy,
                        child: Icon(
                          Icons.meeting_room_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'MeetSpace',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Civic.navy,
                      ),
                    ),
                    Heading(
                      context.t('welcome'),
                      subtitle: context.t('signInIntro'),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.t('email'),
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                      validator: (v) => v == null || !v.contains('@')
                          ? context.t('validEmail')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      obscureText: obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: context.t('password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: context.t('showPassword'),
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? context.t('required') : null,
                    ),
                    if (error != null)
                      Notice(Copy.of(context).error(error!), error: true),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(context.t(busy ? 'signingIn' : 'signIn')),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.t('accountHelp'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Civic.muted, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/machine_profile.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';

class MachinesScreen extends StatelessWidget {
  const MachinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final machineService = context.watch<MachineService>();
    final localization = context.watch<LocaleController>();
    final text = localization.l10n;

    return Scaffold(
      backgroundColor: HmiColors.bg,
      appBar: AppBar(
        backgroundColor: HmiColors.panel,
        foregroundColor: HmiColors.text,
        title: Text(text.t('machines_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            text.t('machines_hint'),
            style: const TextStyle(
              color: HmiColors.textDim,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          ...machineService.machines.map(
            (machine) => _MachineTile(profile: machine),
          ),
          const SizedBox(height: 12),
          _AddMachineCard(
            onAdd: (name, host, port) {
              machineService.addMachine(
                name: name,
                host: host,
                port: port,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MachineTile extends StatelessWidget {
  final MachineProfile profile;

  const _MachineTile({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final machineService = context.watch<MachineService>();
    final text = context.watch<LocaleController>().l10n;

    final isActive = machineService.activeMachine.id == profile.id;
    final isLinked = isActive && machineService.runtimeLinked;
    final isConnecting =
        isActive && machineService.isConnectingMachine;

    return Card(
      color: isActive ? HmiColors.panel : HmiColors.panelAlt,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isActive ? HmiColors.accent : HmiColors.border,
          width: isActive ? 1.4 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.wifi_tethering,
          color: isLinked
              ? HmiColors.ready
              : isConnecting
                  ? HmiColors.warn
                  : HmiColors.textDim,
        ),
        title: Text(
          profile.name,
          style: const TextStyle(
            color: HmiColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${profile.host}:${profile.port}',
          style: const TextStyle(
            color: HmiColors.textDim,
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isLinked)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: HmiColors.ready,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LINKED',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              )
            else
              ElevatedButton(
                onPressed: isConnecting
                    ? null
                    : () => machineService.connectToMachine(profile),
                child: Text(
                  isConnecting
                      ? text.t('connecting')
                      : text.t('connect'),
                ),
              ),
            if (profile.id != 'local')
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: HmiColors.alarm,
                ),
                onPressed: () {
                  machineService.removeMachine(profile.id);
                },
                tooltip: text.t('remove_machine'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddMachineCard extends StatefulWidget {
  final void Function(String name, String host, int port) onAdd;

  const _AddMachineCard({
    required this.onAdd,
  });

  @override
  State<_AddMachineCard> createState() => _AddMachineCardState();
}

class _AddMachineCardState extends State<_AddMachineCard> {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '9100');

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.watch<LocaleController>().l10n;

    return Card(
      color: HmiColors.panelAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(
          color: HmiColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.t('add_machine'),
              style: const TextStyle(
                color: HmiColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              style: const TextStyle(
                color: HmiColors.text,
              ),
              decoration: InputDecoration(
                labelText: text.t('machine_name'),
                hintText: 'e.g. Machine 2 — Line B',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    style: const TextStyle(
                      color: HmiColors.text,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'IP (WiFi)',
                      hintText: '192.168.1.42',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _portController,
                    style: const TextStyle(
                      color: HmiColors.text,
                    ),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(text.t('add_machine')),
                onPressed: _addMachine,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addMachine() {
    final host = _hostController.text.trim();

    if (host.isEmpty) {
      return;
    }

    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    widget.onAdd(
      _nameController.text.trim(),
      host,
      port,
    );

    _nameController.clear();
    _hostController.clear();
    _portController.text = '9100';
  }
}
/// Flackle permission bits (33-bit decimal strings in API payloads).
library;

class Permission {
  static const viewChannel = 1 << 0;
  static const sendMessages = 1 << 1;
  static const attachFiles = 1 << 2;
  static const manageMessages = 1 << 3;
  static const mentionEveryone = 1 << 4;
  static const createInvite = 1 << 5;
  static const kickMembers = 1 << 6;
  static const banMembers = 1 << 7;
  static const manageChannels = 1 << 8;
  static const manageRoles = 1 << 9;
  static const manageServer = 1 << 10;
  static const changeNickname = 1 << 11;
  static const manageNicknames = 1 << 12;
  static const administrator = 1 << 13;
  static const addReactions = 1 << 14;
  static const connect = 1 << 15;
  static const speak = 1 << 16;
  static const muteMembers = 1 << 17;
  static const moveMembers = 1 << 18;
  static const deafenMembers = 1 << 20;
  static const useVideo = 1 << 21;
  static const manageMembers = 1 << 22;
  static const viewGeneralStats = 1 << 24;
  static const viewElevatedStats = 1 << 25;
  static const bypassSlowmode = 1 << 26;
  static const timeoutMembers = 1 << 27;
  static const bulkDelete = 1 << 28;
  static const viewAuditLog = 1 << 29;
  static const managePermissions = 1 << 30;
  static const pinMessages = 1 << 31;
  static const saveMedia = 1 << 32;

  static final BigInt all = (BigInt.one << 33) - BigInt.one;

  static const Map<String, int> bits = {
    'ViewChannel': viewChannel,
    'SendMessages': sendMessages,
    'AttachFiles': attachFiles,
    'ManageMessages': manageMessages,
    'MentionEveryone': mentionEveryone,
    'CreateInvite': createInvite,
    'KickMembers': kickMembers,
    'BanMembers': banMembers,
    'ManageChannels': manageChannels,
    'ManageRoles': manageRoles,
    'ManageServer': manageServer,
    'ChangeNickname': changeNickname,
    'ManageNicknames': manageNicknames,
    'Administrator': administrator,
    'AddReactions': addReactions,
    'Connect': connect,
    'Speak': speak,
    'MuteMembers': muteMembers,
    'MoveMembers': moveMembers,
    'DeafenMembers': deafenMembers,
    'UseVideo': useVideo,
    'ManageMembers': manageMembers,
    'ViewGeneralStats': viewGeneralStats,
    'ViewElevatedStats': viewElevatedStats,
    'BypassSlowmode': bypassSlowmode,
    'TimeoutMembers': timeoutMembers,
    'BulkDelete': bulkDelete,
    'ViewAuditLog': viewAuditLog,
    'ManagePermissions': managePermissions,
    'PinMessages': pinMessages,
    'SaveMedia': saveMedia,
  };

  static const Map<String, String> labels = {
    'ViewChannel': 'View channels',
    'SendMessages': 'Send messages',
    'AttachFiles': 'Attach files',
    'ManageMessages': 'Manage messages',
    'MentionEveryone': 'Mention everyone',
    'CreateInvite': 'Create invites',
    'KickMembers': 'Kick members',
    'BanMembers': 'Ban members',
    'ManageChannels': 'Manage channels',
    'ManageRoles': 'Manage roles',
    'ManageServer': 'Manage server',
    'ChangeNickname': 'Change nickname',
    'ManageNicknames': 'Manage nicknames',
    'Administrator': 'Administrator',
    'AddReactions': 'Add reactions',
    'Connect': 'Connect to voice',
    'Speak': 'Speak',
    'MuteMembers': 'Mute members',
    'MoveMembers': 'Move members',
    'DeafenMembers': 'Deafen members',
    'UseVideo': 'Use video',
    'ManageMembers': 'Manage members',
    'ViewGeneralStats': 'View stats',
    'ViewElevatedStats': 'View elevated stats',
    'BypassSlowmode': 'Bypass slowmode',
    'TimeoutMembers': 'Timeout members',
    'BulkDelete': 'Bulk delete messages',
    'ViewAuditLog': 'View audit log',
    'ManagePermissions': 'Manage permissions',
    'PinMessages': 'Pin messages',
    'SaveMedia': 'Save media',
  };

  static BigInt parse(Object? value) {
    if (value == null) return BigInt.zero;
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    final text = '$value'.trim();
    if (text.isEmpty || text == '0') return BigInt.zero;
    return BigInt.tryParse(text) ?? BigInt.zero;
  }

  static bool has(Object? value, int permission) {
    final bitsValue = parse(value);
    if ((bitsValue & BigInt.from(administrator)) != BigInt.zero) return true;
    final bit = BigInt.from(permission);
    return (bitsValue & bit) == bit;
  }

  static List<String> list(Object? value) {
    final bitsValue = parse(value);
    return bits.keys
        .where((name) => (bitsValue & BigInt.from(bits[name]!)) != BigInt.zero)
        .toList();
  }
}

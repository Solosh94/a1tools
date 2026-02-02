// Comprehensive Inspection Data Model
//
// Based on the A1 Chimney Inspection Report template.
// Supports Electric, Furnace, Masonry Fireplace, Built-In Fireplace, and Wood Stove systems.

import 'dart:typed_data';

/// System types available for inspection
class SystemTypes {
  static const String electric = 'Electric';
  static const String furnace = 'Furnace';
  static const String masonryFireplace = 'Masonry Fireplace';
  static const String builtInFireplace = 'Built-In Fireplace';
  static const String woodStove = 'Wood Stove';

  static const List<String> all = [
    electric,
    furnace,
    masonryFireplace,
    builtInFireplace,
    woodStove,
  ];
}

/// Inspection levels
class InspectionLevels {
  static const String level1 = 'Inspection Level 1';
  static const String level2 = 'Inspection Level 2';
  static const String level3 = 'Inspection Level 3';

  static const List<String> all = [level1, level2, level3];

  static String getDescription(String level) {
    switch (level) {
      case level1:
        return 'Basic visual inspection of accessible areas';
      case level2:
        return 'Includes exterior inspection and accessible attic/crawl spaces';
      case level3:
        return 'Comprehensive inspection including concealed areas';
      default:
        return '';
    }
  }
}

/// Reason for inspection options
class InspectionReasons {
  static const List<String> all = [
    'Annual Inspection',
    'Pre-Purchase Inspection',
    'Post-Fire Inspection',
    'Insurance Claim',
    'Malfunction/Problem',
    'New Installation',
    'Other',
  ];
}

/// Standard condition options
class ConditionOptions {
  static const String meetsStandards = 'Meets Industry Standards';
  static const String doesNotMeet = 'Does Not Meet Industry Standards';

  static const List<String> standard = [meetsStandards, doesNotMeet];

  static const List<String> sootCondition = [
    'Cleaned / Swept',
    'Light Buildup',
    'Moderate Buildup',
    'Heavy Buildup',
    'Glazed Creosote',
  ];

  static const List<String> linerCondition = [
    'Meets Industry Standards',
    'Does Not Meet Industry Standards',
    'Liner Does Not Exist',
  ];

  static const List<String> crownCondition = [
    'Meets Industry Standards',
    'Does Not Meet Industry Standards',
    'Crown Does Not Exist',
  ];

  static const List<String> capCondition = [
    'Meets Industry Standards',
    'Does Not Meet Industry Standards',
    'Chimney Cap Does Not Exist',
  ];

  static const List<String> sparkArrestorCondition = [
    'Meets Industry Standards',
    'Does Not Meet Industry Standards',
    'Spark Arrestor Does Not Exist',
  ];

  static const List<String> cricketCondition = [
    'Meets Industry Standards',
    'Does Not Meet Industry Standards',
    'Chimney Needs Cricket',
  ];

  static const List<String> smokeChsmber = [
    'Parged Smooth',
    'Does Not Parged Smooth',
  ];

  static const List<String> pipeConnection = [
    'Sealed / Connected',
    'Unsealed / Unconnected',
  ];

  static const List<String> cleanoutDoor = [
    'Tight-Fitting / Noncombustible Cover',
    'Untight-Fitting / Combustible Cover',
  ];

  static const List<String> refractoryPanels = [
    'Good Condition',
    'Cracked / Missing',
  ];

  static const List<String> remoteSystem = [
    'Working Properly',
    'Needs Attention',
  ];

  static const List<String> exteriorPipe = [
    'Sealed / Connected',
    'Unsealed / Unconnected',
    'Other',
  ];
}

/// Furnace burning types
class BurningTypes {
  static const List<String> all = [
    'Gas / Oil Burner',
    'Solid Fuel',
    'Wood Burning',
    'Pellet Burning',
  ];
}

/// Furnace piping types
class FurnacePipingTypes {
  static const List<String> all = [
    'B-Vent',
    'L-Vent',
    'Direct Vent',
    'Single Wall Vent',
    'Other',
  ];
}

/// Flue ventilation types
class FlueVentilationTypes {
  static const List<String> all = [
    'Masonry / Bricks',
    'Roof Metal Pipe',
    'Side Wall Metal Pipe',
    'Siding Covered',
  ];

  static const List<String> woodStove = [
    'Masonry / Bricks',
    'Single Wall Metal Pipe',
  ];
}

/// Wood stove types
class WoodStoveTypes {
  static const List<String> all = [
    'Free Standing',
    'Insert',
  ];
}

/// Gas starter types
class GasStarterTypes {
  static const List<String> all = [
    'Gas Key Valve',
    'Remote / Pilot Light Starter',
    'No Gas Connection',
  ];
}

/// Gas fuel types
class GasFuelTypes {
  static const String natural = 'Natural';
  static const String propane = 'Propane';

  static const List<String> all = [natural, propane];
}

/// Electric system types
class ElectricSystemTypes {
  static const List<String> all = [
    'Wall Mounted',
    'Insert',
    'Free Standing',
    'Built-In',
  ];
}

/// Electric starter types
class ElectricStarterTypes {
  static const List<String> all = [
    'Remote Control',
    'Wall Switch',
    'Manual Button',
  ];
}

/// Firebox repair needs
class FireboxRepairNeeds {
  static const List<String> all = [
    'Cracked Firebricks',
    'Missing Firebricks',
    'Deteriorating Mortar',
    'Spalling Bricks',
    'Heat Damage',
    'Other',
  ];
}

/// Gas line repair needs
class GasLineRepairNeeds {
  static const List<String> all = [
    'Gas Leak Detected',
    'Corroded Pipes',
    'Damaged Valve',
    'Improper Connection',
    'Other',
  ];
}

/// Damper repair needs
class DamperRepairNeeds {
  static const List<String> all = [
    'Stuck Open',
    'Stuck Closed',
    'Missing Handle',
    'Rusted/Corroded',
    'Warped',
    'Other',
  ];
}

/// Masonry work issues
class MasonryWorkIssues {
  static const List<String> all = [
    'Cracked Bricks',
    'Missing Mortar',
    'Spalling',
    'Efflorescence',
    'Leaning Structure',
    'Water Damage',
    'Other',
  ];
}

/// Image field attached to an inspection item
class InspectionImage {
  final String fieldName;
  final Uint8List? bytes;
  final String? base64Data;
  final String? filename;
  final String? url; // For already uploaded images

  InspectionImage({
    required this.fieldName,
    this.bytes,
    this.base64Data,
    this.filename,
    this.url,
  });

  bool get hasImage => bytes != null || url != null;

  Map<String, dynamic> toJson() => {
        'field_name': fieldName,
        'data': base64Data,
        'filename': filename,
        'url': url,
      };

  factory InspectionImage.fromJson(Map<String, dynamic> json) {
    return InspectionImage(
      fieldName: json['field_name'] ?? '',
      url: json['url'],
      filename: json['filename'],
    );
  }
}

/// Comprehensive inspection form data
class InspectionFormData {
  // Job Info
  String? jobId;
  DateTime inspectionDate;
  String inspectionTime;
  String inspectorName;
  String inspectionLevel;
  String reasonForInspection;
  String? otherReason;

  // Client Info
  String firstName;
  String lastName;
  String address1;
  String? address2;
  String city;
  String state;
  String zipCode;
  String phone;
  String email1;
  String? email2;
  bool onSiteClient;

  // System Type
  String systemType;

  // Exterior Home Image
  InspectionImage? exteriorHomeImage;

  // ========== ELECTRIC SYSTEM FIELDS ==========
  bool? electricSystemWorking;
  String? electricSystemType;
  String? electricStarterType;
  String? electricFireplaceCondition;
  String? electricFireplaceWidth;
  String? electricFireplaceHeight;
  InspectionImage? electricFireplaceImage;

  // ========== FURNACE SYSTEM FIELDS ==========
  String? burningType;
  String? furnaceBrand;
  String? furnaceModelNo;
  String? furnaceVisualInspection;
  String? furnaceVisualInspectionExplanation;
  InspectionImage? furnaceVisualInspectionImage;
  String? furnaceClearance;
  InspectionImage? furnaceClearanceImage;
  String? furnaceVenting; // 'Vented' or 'Unvented'
  String? furnacePipingType;
  String? otherFurnacePipingTypeExplanation;
  String? pipeClearance;
  InspectionImage? pipeClearanceImage;
  String? furnacePipeCircumference;
  String? furnacePipeDiameter;
  String? furnacePipesConnection;
  InspectionImage? furnacePipesConnectionImage;
  String? furnacePipeSootCondition;
  InspectionImage? furnacePipeSootConditionImage;
  String? boilerPipesCondition;
  String? boilerPipeConnection;
  InspectionImage? boilerPipesConnectionImage;
  String? otherBoilerPipesCondition;
  InspectionImage? otherBoilerPipesConditionImage;
  InspectionImage? furnaceImage;

  // ========== MASONRY FIREPLACE FIELDS ==========
  String? fireplaceWidth;
  String? fireplaceHeight;
  String? fireplaceDepth;
  String? fireplaceDimensions; // Calculated sq ft
  String? hearthExtensionFront;
  String? hearthExtensionSide;
  bool? hearthExtensionRegulation;
  InspectionImage? hearthExtensionImage;
  String? fireplaceClearanceToCombustibles;
  InspectionImage? fireplaceClearanceToCombustiblesImage;
  String? fireplaceGlassDoor;
  String? fireplaceGlassDoorExplanation;
  InspectionImage? fireplaceGlassDoorImage;
  String? fireboxCondition;
  List<String>? fireboxRepairNeeds;
  String? otherFireboxRepairNeed;
  InspectionImage? fireboxImage;
  String? ashDump;
  InspectionImage? ashDumpImage;
  String? gasLine;
  List<String>? gasLineRepairNeeds;
  String? otherGasLineRepairNeed;
  InspectionImage? gasLineImage;
  String? damper;
  List<String>? damperRepairNeeds;
  String? otherDamperRepairNeed;
  InspectionImage? damperImage;
  String? smokeChamber;
  InspectionImage? smokeChamberImage;
  String? masonrySoot;
  InspectionImage? masonrySootImage;
  InspectionImage? masonryFireplaceImage;

  // ========== BUILT-IN FIREPLACE FIELDS ==========
  String? builtInWidth;
  String? builtInHeight;
  String? builtInDepth;
  String? builtInModelNo;
  String? builtInSerialNo;
  String? builtInHearth;
  String? builtInHearthExplanation;
  InspectionImage? builtInHearthImage;
  String? builtInClearance;
  String? builtInClearanceExplanation;
  InspectionImage? builtInClearanceImage;
  String? glassDoorCondition;
  String? glassDoorConditionExplanation;
  InspectionImage? glassDoorConditionImage;
  bool? builtInGasConnection;
  String? gasFuelType; // Natural or Propane
  String? gasStarterType;
  String? gasLineBurner;
  List<String>? gasLineBurnerRepairNeeds;
  String? otherGasLineBurnerRepairNeeds;
  InspectionImage? gasLineBurnerImage;
  String? gasValveCondition;
  String? gasValveConditionExplanation;
  InspectionImage? gasValveConditionImage;
  String? pilotLightCondition;
  String? pilotLightConditionExplanation;
  InspectionImage? pilotLightConditionImage;
  String? thermocoupleCondition;
  String? thermocoupleConditionExplanation;
  InspectionImage? thermocoupleConditionImage;
  String? remoteSystemCondition;
  String? remoteSystemConditionExplanation;
  String? refractoryPanelsCondition;
  InspectionImage? refractoryPanelsConditionImage;
  bool? systemVented;
  String? builtInDamper;
  List<String>? builtInDamperRepairNeeds;
  String? otherBuiltInDamperRepairNeeds;
  InspectionImage? builtInDamperImage;
  String? builtInSoot;
  InspectionImage? builtInSootImage;
  InspectionImage? builtInFireplaceImage;
  InspectionImage? fireplaceModelImage;

  // ========== WOOD STOVE FIELDS ==========
  String? woodStoveType;
  String? stoveClearanceToCombustibles;
  String? stoveClearanceToCombustiblesExplanation;
  InspectionImage? stoveClearanceToCombustiblesImage;
  String? stoveCondition;
  String? stoveConditionExplanation;
  InspectionImage? stoveConditionImage;
  String? freeStandingPipesCircumference;
  String? freeStandingPipesDiameter;
  String? freeStandingPipesConnection;
  InspectionImage? freeStandingPipesConnectionImage;
  String? stoveSootCondition;
  InspectionImage? stoveSootConditionImage;
  String? flueVentilationType2; // For wood stove
  InspectionImage? woodStoveImage;

  // ========== COMMON CHIMNEY FIELDS ==========
  String? flueVentilationType;
  String? cleanoutDoor;
  InspectionImage? cleanoutDoorImage;
  String? sideWallMetalPipeCondition;
  String? sideWallMetalPipeConditionExplanation;
  String? chimneyLiner;
  String? chimneyLinerExplanation;
  InspectionImage? chimneyLinerImage;

  // ========== EXTERIOR/ROOF INSPECTION (Level 2+) ==========
  InspectionImage? exteriorChimneyTypeImage;
  String? chimneyHeightFromRoofLine;
  InspectionImage? chimneyHeightFromRoofLineImage;
  String? chimneyCricket;
  InspectionImage? chimneyCricketImage;
  String? flushingCondition;
  InspectionImage? flushingConditionImage;
  String? chimneySidingCoverCondition;
  InspectionImage? chimneySidingCoverConditionImage;
  String? chaseCoveringCondition;
  InspectionImage? chaseCoveringConditionImage;
  String? exteriorPipeCondition;
  String? exteriorPipeConditionExplanation;
  InspectionImage? exteriorPipeConditionImage;
  String? masonryWorkCondition;
  List<String>? masonryWorkIssues;
  String? otherMasonryIssue;
  InspectionImage? masonryWorkImage;
  String? chimneyCrownCondition;
  InspectionImage? chimneyCrownImage;
  String? chimneyRainCap;
  InspectionImage? chimneyRainCapImage;
  String? chimneySparkArrestor;
  InspectionImage? chimneySparkArrestorImage;

  // ========== INSPECTOR NOTE ==========
  String? inspectorNote;

  // ========== SIGNATURES ==========
  InspectionImage? clientSignature;
  InspectionImage? inspectorSignature;

  // ========== WORKIZ INTEGRATION ==========
  String? workizJobUuid;
  String? workizJobSerial;
  String? workizClientId;

  InspectionFormData({
    this.jobId,
    DateTime? inspectionDate,
    String? inspectionTime,
    required this.inspectorName,
    this.inspectionLevel = 'Inspection Level 1',
    this.reasonForInspection = 'Annual Inspection',
    this.otherReason,
    this.firstName = '',
    this.lastName = '',
    this.address1 = '',
    this.address2,
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.phone = '',
    this.email1 = '',
    this.email2,
    this.onSiteClient = true,
    this.systemType = 'Masonry Fireplace',
    // ... all other optional fields
  })  : inspectionDate = inspectionDate ?? DateTime.now(),
        inspectionTime = inspectionTime ?? _formatTime(DateTime.now());

  static String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  /// Get all images for upload
  List<InspectionImage> getAllImages() {
    final images = <InspectionImage>[];

    void addIfNotNull(InspectionImage? img) {
      if (img != null && img.hasImage) images.add(img);
    }

    addIfNotNull(exteriorHomeImage);
    addIfNotNull(electricFireplaceImage);
    addIfNotNull(furnaceImage);
    addIfNotNull(furnaceVisualInspectionImage);
    addIfNotNull(furnaceClearanceImage);
    addIfNotNull(pipeClearanceImage);
    addIfNotNull(furnacePipesConnectionImage);
    addIfNotNull(furnacePipeSootConditionImage);
    addIfNotNull(boilerPipesConnectionImage);
    addIfNotNull(otherBoilerPipesConditionImage);
    addIfNotNull(masonryFireplaceImage);
    addIfNotNull(hearthExtensionImage);
    addIfNotNull(fireplaceClearanceToCombustiblesImage);
    addIfNotNull(fireplaceGlassDoorImage);
    addIfNotNull(fireboxImage);
    addIfNotNull(ashDumpImage);
    addIfNotNull(gasLineImage);
    addIfNotNull(damperImage);
    addIfNotNull(smokeChamberImage);
    addIfNotNull(masonrySootImage);
    addIfNotNull(builtInFireplaceImage);
    addIfNotNull(fireplaceModelImage);
    addIfNotNull(builtInHearthImage);
    addIfNotNull(builtInClearanceImage);
    addIfNotNull(glassDoorConditionImage);
    addIfNotNull(gasLineBurnerImage);
    addIfNotNull(gasValveConditionImage);
    addIfNotNull(pilotLightConditionImage);
    addIfNotNull(thermocoupleConditionImage);
    addIfNotNull(refractoryPanelsConditionImage);
    addIfNotNull(builtInDamperImage);
    addIfNotNull(builtInSootImage);
    addIfNotNull(woodStoveImage);
    addIfNotNull(stoveClearanceToCombustiblesImage);
    addIfNotNull(stoveConditionImage);
    addIfNotNull(freeStandingPipesConnectionImage);
    addIfNotNull(stoveSootConditionImage);
    addIfNotNull(cleanoutDoorImage);
    addIfNotNull(chimneyLinerImage);
    addIfNotNull(exteriorChimneyTypeImage);
    addIfNotNull(chimneyHeightFromRoofLineImage);
    addIfNotNull(chimneyCricketImage);
    addIfNotNull(flushingConditionImage);
    addIfNotNull(chimneySidingCoverConditionImage);
    addIfNotNull(chaseCoveringConditionImage);
    addIfNotNull(exteriorPipeConditionImage);
    addIfNotNull(masonryWorkImage);
    addIfNotNull(chimneyCrownImage);
    addIfNotNull(chimneyRainCapImage);
    addIfNotNull(chimneySparkArrestorImage);
    addIfNotNull(clientSignature);
    addIfNotNull(inspectorSignature);

    return images;
  }

  /// Convert to JSON for API submission
  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'inspection_date': inspectionDate.toIso8601String(),
      'inspection_time': inspectionTime,
      'inspector_name': inspectorName,
      'inspection_level': inspectionLevel,
      'reason_for_inspection': reasonForInspection,
      'other_reason': otherReason,
      'first_name': firstName,
      'last_name': lastName,
      'address1': address1,
      'address2': address2,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'phone': phone,
      'email1': email1,
      'email2': email2,
      'on_site_client': onSiteClient,
      'system_type': systemType,

      // Electric fields
      'electric_system_working': electricSystemWorking,
      'electric_system_type': electricSystemType,
      'electric_starter_type': electricStarterType,
      'electric_fireplace_condition': electricFireplaceCondition,
      'electric_fireplace_width': electricFireplaceWidth,
      'electric_fireplace_height': electricFireplaceHeight,

      // Furnace fields
      'burning_type': burningType,
      'furnace_brand': furnaceBrand,
      'furnace_model_no': furnaceModelNo,
      'furnace_visual_inspection': furnaceVisualInspection,
      'furnace_visual_inspection_explanation': furnaceVisualInspectionExplanation,
      'furnace_clearance': furnaceClearance,
      'furnace_venting': furnaceVenting,
      'furnace_piping_type': furnacePipingType,
      'other_furnace_piping_type_explanation': otherFurnacePipingTypeExplanation,
      'pipe_clearance': pipeClearance,
      'furnace_pipe_circumference': furnacePipeCircumference,
      'furnace_pipe_diameter': furnacePipeDiameter,
      'furnace_pipes_connection': furnacePipesConnection,
      'furnace_pipe_soot_condition': furnacePipeSootCondition,
      'boiler_pipes_condition': boilerPipesCondition,
      'boiler_pipe_connection': boilerPipeConnection,
      'other_boiler_pipes_condition': otherBoilerPipesCondition,

      // Masonry fireplace fields
      'f_width': fireplaceWidth,
      'f_height': fireplaceHeight,
      'f_depth': fireplaceDepth,
      'fireplace_dimensions': fireplaceDimensions,
      'hearth_e_front': hearthExtensionFront,
      'hearth_e_side': hearthExtensionSide,
      'hearth_extension_regulation': hearthExtensionRegulation,
      'fireplace_clearance_to_combustibles': fireplaceClearanceToCombustibles,
      'fireplace_glass_door': fireplaceGlassDoor,
      'fireplace_glass_door_exp': fireplaceGlassDoorExplanation,
      'firebox_condition': fireboxCondition,
      'firebox_repair_needs': fireboxRepairNeeds,
      'other_repair_need': otherFireboxRepairNeed,
      'ash_dump': ashDump,
      'gas_line': gasLine,
      'gas_line_repair_needs': gasLineRepairNeeds,
      'other_gas_line_repair_need': otherGasLineRepairNeed,
      'damper': damper,
      'damper_repair_needs': damperRepairNeeds,
      'other_damper_repair_need': otherDamperRepairNeed,
      'smoke_chamber': smokeChamber,
      'masonry_soot': masonrySoot,

      // Built-in fireplace fields
      'built_in_width': builtInWidth,
      'built_in_height': builtInHeight,
      'built_in_depth': builtInDepth,
      'built_in_model_no': builtInModelNo,
      'built_in_serial_no': builtInSerialNo,
      'built_in_hearth': builtInHearth,
      'built_in_hearth_exp': builtInHearthExplanation,
      'built_in_clearance': builtInClearance,
      'built_in_clearance_exp': builtInClearanceExplanation,
      'glass_door_condition': glassDoorCondition,
      'glass_door_condition_exp': glassDoorConditionExplanation,
      'built_in_gas_connection': builtInGasConnection,
      'gas_fuel_type': gasFuelType,
      'gas_starter_type': gasStarterType,
      'gas_line_burner': gasLineBurner,
      'gas_line_burner_repair_needs': gasLineBurnerRepairNeeds,
      'other_gas_line_burner_repair_needs': otherGasLineBurnerRepairNeeds,
      'gas_valve_condition': gasValveCondition,
      'gas_valve_condition_exp': gasValveConditionExplanation,
      'pilot_light_condition': pilotLightCondition,
      'pilot_light_condition_exp': pilotLightConditionExplanation,
      'thermocouple_condition': thermocoupleCondition,
      'thermocouple_condition_exp': thermocoupleConditionExplanation,
      'remote_system_condition': remoteSystemCondition,
      'remote_system_condition_exp': remoteSystemConditionExplanation,
      'refractory_panels_condition': refractoryPanelsCondition,
      'system_vented': systemVented,
      'built_in_damper': builtInDamper,
      'built_in_damper_repair_needs': builtInDamperRepairNeeds,
      'other_built_in_damper_repair_needs': otherBuiltInDamperRepairNeeds,
      'built_in_soot': builtInSoot,

      // Wood stove fields
      'wood_stove_type': woodStoveType,
      'stove_ctc': stoveClearanceToCombustibles,
      'stove_ctc_exp': stoveClearanceToCombustiblesExplanation,
      'stove_condition': stoveCondition,
      'stove_condition_exp': stoveConditionExplanation,
      'free_standing_pipes_circumference': freeStandingPipesCircumference,
      'free_standing_pipes_diameter': freeStandingPipesDiameter,
      'fs_pipes_connections': freeStandingPipesConnection,
      'stove_soot_condition': stoveSootCondition,
      'flue_ventilation_type_2': flueVentilationType2,

      // Common chimney fields
      'flue_ventilation_type': flueVentilationType,
      'cleanout_door_1': cleanoutDoor,
      'side_wall_metal_pipe_condition': sideWallMetalPipeCondition,
      'side_wall_metal_pipe_condition_exp': sideWallMetalPipeConditionExplanation,
      'chimney_liner': chimneyLiner,
      'chimney_liner_explanation': chimneyLinerExplanation,

      // Exterior/roof fields (Level 2+)
      'chimney_height_from_roof_line': chimneyHeightFromRoofLine,
      'chimney_cricket': chimneyCricket,
      'flushing_condition': flushingCondition,
      'chimney_siding_cover_condition': chimneySidingCoverCondition,
      'chase_covering_condition': chaseCoveringCondition,
      'exterior_pipe_condition': exteriorPipeCondition,
      'masonry_work_condition': masonryWorkCondition,
      'masonry_work_issues': masonryWorkIssues,
      'other_masonry_issue': otherMasonryIssue,
      'chimney_crown_condition': chimneyCrownCondition,
      'chimney_rain_cap': chimneyRainCap,
      'chimney_spark_arrestor': chimneySparkArrestor,

      // Inspector note
      'inspector_note': inspectorNote,

      // Workiz integration
      'workiz_job_uuid': workizJobUuid,
      'workiz_job_serial': workizJobSerial,
      'workiz_client_id': workizClientId,

      // Images (base64 encoded)
      'images': getAllImages().map((img) => img.toJson()).toList(),
    };
  }
}

/// Failed inspection item for summary
class FailedInspectionItem {
  final String item;
  final String status;
  final String code;

  FailedInspectionItem({
    required this.item,
    this.status = 'Failed',
    required this.code,
  });
}

/// Get list of failed items from inspection data
List<FailedInspectionItem> getFailedItems(InspectionFormData data) {
  final items = <FailedInspectionItem>[];

  // Furnace clearance
  if (data.burningType == 'Gas / Oil Burner' &&
      data.furnaceClearance == ConditionOptions.doesNotMeet) {
    items.add(FailedInspectionItem(
      item: 'Furnace Clearance to Combustibles',
      code: 'INSPECTION FAILED BY THE CODE 603.5.3.1 GAS OR FUEL-OIL HEATERS',
    ));
  }
  if ((data.burningType == 'Solid Fuel' || data.burningType == 'Wood Burning') &&
      data.furnaceClearance == ConditionOptions.doesNotMeet) {
    items.add(FailedInspectionItem(
      item: 'Furnace Clearance to Combustibles',
      code: 'INSPECTION FAILED BY THE CODE 603.5.3.2 SOLID FUEL-BURNING HEATERS',
    ));
  }

  // Pipe clearance
  if ((data.furnacePipingType == 'B-Vent' || data.furnacePipingType == 'L-Vent') &&
      data.pipeClearance == ConditionOptions.doesNotMeet) {
    items.add(FailedInspectionItem(
      item: 'Pipe Clearance to Combustibles',
      code: 'INSPECTION FAILED BY CODE M1803.3.4 CLEARANCE',
    ));
  }

  // Furnace pipe connection
  if (data.furnacePipesConnection == 'Unsealed / Unconnected') {
    items.add(FailedInspectionItem(
      item: 'Furnace Pipe Connection',
      code: 'INSPECTION FAILED BY CODE 501.7.1 CLOSURE AND ACCESS',
    ));
  }

  // Soot condition
  if (data.furnacePipeSootCondition != null &&
      data.furnacePipeSootCondition != 'Cleaned / Swept') {
    items.add(FailedInspectionItem(
      item: 'Furnace Pipes Soot Condition',
      code: 'INSPECTION FAILED BY THE NATIONAL FIRE PROTECTION ASSOCIATION (NFPA) STANDARD 211',
    ));
  }

  // Firebox depth
  if (data.fireplaceDepth != null) {
    final depth = int.tryParse(data.fireplaceDepth!) ?? 0;
    if (depth > 0 && depth < 20) {
      items.add(FailedInspectionItem(
        item: 'Fireplace Square Foot Dimensions',
        code: 'INSPECTION FAILED BY CODE R1001.6 FIREBOX DIMENSIONS',
      ));
    }
  }

  // Hearth extension
  if (data.hearthExtensionRegulation == false) {
    items.add(FailedInspectionItem(
      item: 'Hearth Extension Dimensions',
      code: 'INSPECTION FAILED BY CODE R1001.10 HEARTH EXTENSION DIMENSIONS',
    ));
  }

  // Fireplace clearance
  if (data.fireplaceClearanceToCombustibles == ConditionOptions.doesNotMeet) {
    items.add(FailedInspectionItem(
      item: 'Fireplace Clearance to Combustibles',
      code: 'INSPECTION FAILED BY CODE R1001.11 CLEARANCES',
    ));
  }

  // Firebox condition
  if (data.fireboxCondition == ConditionOptions.doesNotMeet) {
    items.add(FailedInspectionItem(
      item: 'Firebox Condition',
      code: 'INSPECTION FAILED BY CODE R1001.5 FIREBOX WALLS',
    ));
  }

  // Ash dump
  if (data.ashDump == ConditionOptions.doesNotMeet) {
    items.add(FailedInspectionItem(
      item: 'Ash Dump',
      code: 'INSPECTION FAILED BY CODE R1001.2.1 ASH DUMP CLEANOUT',
    ));
  }

  // Damper
  if (data.damper == ConditionOptions.doesNotMeet) {
    items.add(FailedInspectionItem(
      item: 'Damper',
      code: 'INSPECTION FAILED BY CODE R1001.7.1 DAMPER',
    ));
  }

  // Smoke chamber
  if (data.smokeChamber == 'Does Not Parged Smooth') {
    items.add(FailedInspectionItem(
      item: 'Smoke Chamber',
      code: 'INSPECTION FAILED BY CODE R1001.8 SMOKE CHAMBER',
    ));
  }

  // Masonry soot
  if (data.masonrySoot != null && data.masonrySoot != 'Cleaned / Swept') {
    items.add(FailedInspectionItem(
      item: 'Soot Condition',
      code: 'INSPECTION FAILED BY THE NATIONAL FIRE PROTECTION ASSOCIATION (NFPA) STANDARD 211',
    ));
  }

  // Chimney liner
  if (data.chimneyLiner == 'Does Not Meet Industry Standards' ||
      data.chimneyLiner == 'Liner Does Not Exist') {
    items.add(FailedInspectionItem(
      item: 'Chimney Liner',
      code: 'INSPECTION FAILED BY CODE R1003.11 FLUE LINING (MATERIAL)',
    ));
  }

  // Chimney height (Level 2+)
  if (data.chimneyHeightFromRoofLine == ConditionOptions.doesNotMeet) {
    items.add(FailedInspectionItem(
      item: 'Chimney Height From Roof Line',
      code: 'INSPECTION FAILED BY CODE R1003.9 TERMINATION',
    ));
  }

  // Chimney cricket
  if (data.chimneyCricket == 'Does Not Meet Industry Standards' ||
      data.chimneyCricket == 'Chimney Needs Cricket') {
    items.add(FailedInspectionItem(
      item: 'Chimney Cricket',
      code: 'INSPECTION FAILED BY CODE R1003.20 CHIMNEY CRICKETS',
    ));
  }

  // Flushing condition
  if (data.flushingCondition == ConditionOptions.doesNotMeet) {
    items.add(FailedInspectionItem(
      item: 'Flushing Condition',
      code: 'INSPECTION FAILED BY CODE R903.2 FLUSHING',
    ));
  }

  // Chimney crown
  if (data.chimneyCrownCondition == 'Does Not Meet Industry Standards' ||
      data.chimneyCrownCondition == 'Crown Does Not Exist') {
    items.add(FailedInspectionItem(
      item: 'Chimney Crown Condition',
      code: 'INSPECTION FAILED BY CODE R1003.9.1 CHIMNEY CAP/CROWN',
    ));
  }

  // Chimney rain cap
  if (data.chimneyRainCap == 'Does Not Meet Industry Standards' ||
      data.chimneyRainCap == 'Chimney Cap Does Not Exist') {
    items.add(FailedInspectionItem(
      item: 'Chimney Rain Cap',
      code: 'INSPECTION FAILED BY CODE R1003.9.1 CHIMNEY CAPS',
    ));
  }

  // Spark arrestor
  if (data.chimneySparkArrestor == 'Spark Arrestor Does Not Exist' ||
      data.chimneySparkArrestor == 'Does Not Meet Industry Standards') {
    items.add(FailedInspectionItem(
      item: 'Chimney Spark Arrestor',
      code: 'INSPECTION FAILED BY CODE R1003.9.1 SPARK ARRESTOR SCREEN',
    ));
  }

  return items;
}

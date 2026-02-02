// Training Questions Bank
// 
// Local storage of all training questions and knowledge base content
// organized by test type.

import 'training_models.dart';

/// All available training tests and knowledge bases
class TrainingQuestionBank {
  
  /// Technician Training Test
  static const TrainingTest technicianTest = TrainingTest(
    id: 'technician_test',
    title: 'Technician Certification Test',
    description: 'Complete this test to certify your knowledge as an A-1 Chimney Technician. '
        'You must score at least 80% to pass. You have 3 attempts maximum.',
    targetRole: 'technician',
    passingScore: 0.8,
    maxAttempts: 3,
    questions: _technicianQuestions,
  );

  /// Dispatcher Training Test  
  static const TrainingTest dispatcherTest = TrainingTest(
    id: 'dispatcher_test',
    title: 'Dispatcher Certification Test',
    description: 'Complete this test to certify your knowledge as an A-1 Chimney Dispatcher. '
        'You must score at least 80% to pass. You have 3 attempts maximum.',
    targetRole: 'dispatcher',
    passingScore: 0.8,
    maxAttempts: 3,
    questions: _dispatcherQuestions,
  );

  /// Get all tests
  static List<TrainingTest> get allTests => [technicianTest, dispatcherTest];

  /// Get test by ID
  static TrainingTest? getTestById(String id) {
    switch (id) {
      case 'technician_test':
        return technicianTest;
      case 'dispatcher_test':
        return dispatcherTest;
      default:
        return null;
    }
  }

  /// Get tests available for a role
  static List<TrainingTest> getTestsForRole(String role) {
    switch (role.toLowerCase()) {
      case 'technician':
        return [technicianTest];
      case 'dispatcher':
      case 'remote_dispatcher':
        return [dispatcherTest];
      case 'administrator':
      case 'management':
      case 'developer':
        return [technicianTest, dispatcherTest];
      default:
        return [];
    }
  }

  // ============================================================================
  // KNOWLEDGE BASES
  // ============================================================================

  /// Dispatcher Knowledge Base
  static const KnowledgeBase dispatcherKnowledgeBase = KnowledgeBase(
    id: 'dispatcher_kb',
    title: 'Dispatcher Training Guide',
    description: 'Complete knowledge base for A-1 Chimney Dispatchers. Study this material before taking the certification test.',
    targetRole: 'dispatcher',
    sections: _dispatcherKnowledgeSections,
  );

  /// Technician Knowledge Base
  static const KnowledgeBase technicianKnowledgeBase = KnowledgeBase(
    id: 'technician_kb',
    title: 'Technician Training Guide',
    description: 'Complete knowledge base for A-1 Chimney Technicians. Study this material before taking the certification test.',
    targetRole: 'technician',
    sections: _technicianKnowledgeSections,
  );

  /// Get all knowledge bases
  static List<KnowledgeBase> get allKnowledgeBases => [dispatcherKnowledgeBase, technicianKnowledgeBase];

  /// Get knowledge base by ID
  static KnowledgeBase? getKnowledgeBaseById(String id) {
    switch (id) {
      case 'dispatcher_kb':
        return dispatcherKnowledgeBase;
      case 'technician_kb':
        return technicianKnowledgeBase;
      default:
        return null;
    }
  }

  /// Get knowledge base for a test
  static KnowledgeBase? getKnowledgeBaseForTest(String testId) {
    switch (testId) {
      case 'dispatcher_test':
        return dispatcherKnowledgeBase;
      case 'technician_test':
        return technicianKnowledgeBase;
      default:
        return null;
    }
  }

  /// Get knowledge bases available for a role
  static List<KnowledgeBase> getKnowledgeBasesForRole(String role) {
    switch (role.toLowerCase()) {
      case 'technician':
        return [technicianKnowledgeBase];
      case 'dispatcher':
      case 'remote_dispatcher':
        return [dispatcherKnowledgeBase];
      case 'administrator':
      case 'management':
      case 'developer':
        return [technicianKnowledgeBase, dispatcherKnowledgeBase];
      default:
        return [];
    }
  }
}

/// ============================================================================
/// DISPATCHER KNOWLEDGE BASE SECTIONS
/// ============================================================================

const List<KnowledgeSection> _dispatcherKnowledgeSections = [
  // Placeholder - will be replaced with actual content
  KnowledgeSection(
    id: 'disp_kb_placeholder',
    title: 'Coming Soon',
    icon: '📚',
    topics: [
      KnowledgeTopic(
        id: 'disp_kb_placeholder_1',
        title: 'Knowledge Base Content',
        content: 'The dispatcher knowledge base content will be added here. '
            'This will include all the information you need to study before taking the certification test.',
        keyPoints: [
          'Phone handling procedures',
          'Customer interaction scripts',
          'Workiz job management',
          'Chimney knowledge basics',
          'Company policies and pricing',
        ],
      ),
    ],
  ),
];

/// ============================================================================
/// TECHNICIAN KNOWLEDGE BASE SECTIONS
/// ============================================================================
const List<KnowledgeSection> _technicianKnowledgeSections = [
  // Placeholder - will be replaced with actual content
  KnowledgeSection(
    id: 'tech_kb_placeholder',
    title: 'Coming Soon',
    icon: '📚',
    topics: [
      KnowledgeTopic(
        id: 'tech_kb_placeholder_1',
        title: 'Knowledge Base Content',
        content: 'The technician knowledge base content will be added here. '
            'This will include all the information you need to study before taking the certification test.',
        keyPoints: [
          'Safety procedures',
          'Inspection levels and standards',
          'Chimney components and terminology',
          'Cleaning and repair procedures',
          'Customer service guidelines',
        ],
      ),
    ],
  ),
];

/// ============================================================================
/// TECHNICIAN QUESTIONS
/// ============================================================================
/// Format for each question:
/// - id: Unique identifier (e.g., 'tech_001')
/// - question: The question text
/// - options: List of 4 options (3 incorrect, 1 correct)
/// - correctIndex: Index of the correct answer (0-3)
/// - explanation: (Optional) Explanation shown in study mode
/// - category: (Optional) Category for organization

const List<TrainingQuestion> _technicianQuestions = [
  // === SAFETY CATEGORY ===
  TrainingQuestion(
    id: 'tech_001',
    category: 'Safety',
    question: 'What is the first thing you should do when arriving at a job site?',
    options: [
      'Start unloading equipment immediately',
      'Perform a safety assessment of the work area',
      'Ring the doorbell and introduce yourself',
      'Check your phone for messages',
    ],
    correctIndex: 1,
    explanation: 'Safety is always the first priority. Assess the work area for potential hazards before beginning any work.',
  ),
  TrainingQuestion(
    id: 'tech_002',
    category: 'Safety',
    question: 'When working on a roof, what is the minimum pitch that requires fall protection?',
    options: [
      '2/12 pitch',
      '4/12 pitch',
      '6/12 pitch',
      '8/12 pitch',
    ],
    correctIndex: 1,
    explanation: 'OSHA requires fall protection for roof pitches of 4/12 or greater, or any roof more than 6 feet above ground.',
  ),
  TrainingQuestion(
    id: 'tech_003',
    category: 'Safety',
    question: 'What type of fire extinguisher should be readily available during chimney cleaning?',
    options: [
      'Class A only',
      'Class B only',
      'Class ABC',
      'Class D',
    ],
    correctIndex: 2,
    explanation: 'A Class ABC extinguisher handles ordinary combustibles, flammable liquids, and electrical fires - all potential hazards during chimney work.',
  ),

  // === CHIMNEY INSPECTION CATEGORY ===
  TrainingQuestion(
    id: 'tech_004',
    category: 'Inspection',
    question: 'What are the three levels of chimney inspection as defined by NFPA 211?',
    options: [
      'Basic, Standard, Advanced',
      'Level I, Level II, Level III',
      'Visual, Partial, Complete',
      'Quick, Normal, Thorough',
    ],
    correctIndex: 1,
    explanation: 'NFPA 211 defines three inspection levels: Level I (readily accessible), Level II (accessible areas including attic/crawlspace), and Level III (removal of components).',
  ),
  TrainingQuestion(
    id: 'tech_005',
    category: 'Inspection',
    question: 'When is a Level II inspection required?',
    options: [
      'Only when selling a home',
      'During routine annual maintenance',
      'After a change in fuel type, malfunction, or before property transfer',
      'Only when visible damage is present',
    ],
    correctIndex: 2,
    explanation: 'Level II inspections are required after any changes to the system, after malfunctions or external events, and before property transfers.',
  ),
  TrainingQuestion(
    id: 'tech_006',
    category: 'Inspection',
    question: 'What tool is essential for performing a Level II chimney inspection?',
    options: [
      'Flashlight only',
      'Video camera/scope',
      'Measuring tape',
      'Smoke pencil',
    ],
    correctIndex: 1,
    explanation: 'A video camera or scope is essential for Level II inspections to view areas not directly accessible.',
  ),

  // === CHIMNEY CLEANING CATEGORY ===
  TrainingQuestion(
    id: 'tech_007',
    category: 'Cleaning',
    question: 'What is the recommended maximum thickness of creosote buildup before cleaning is required?',
    options: [
      '1/16 inch',
      '1/8 inch',
      '1/4 inch',
      '1/2 inch',
    ],
    correctIndex: 1,
    explanation: 'The CSIA recommends cleaning when creosote buildup reaches 1/8 inch to prevent chimney fires.',
  ),
  TrainingQuestion(
    id: 'tech_008',
    category: 'Cleaning',
    question: 'What are the three stages/degrees of creosote?',
    options: [
      'Light, Medium, Heavy',
      'Soft, Hard, Glazed',
      'First degree (dusty), Second degree (flaky), Third degree (glazed)',
      'Surface, Deep, Embedded',
    ],
    correctIndex: 2,
    explanation: 'First degree is dusty/sooty, second degree is flaky/crunchy, and third degree is glazed/hardened - the most dangerous.',
  ),
  TrainingQuestion(
    id: 'tech_009',
    category: 'Cleaning',
    question: 'Which cleaning method is most appropriate for third-degree (glazed) creosote?',
    options: [
      'Standard wire brush',
      'Rotary cleaning system with chemical treatment',
      'Vacuum only',
      'Water spray',
    ],
    correctIndex: 1,
    explanation: 'Glazed creosote requires chemical treatment to break down the hardened deposits, followed by rotary cleaning.',
  ),

  // === REPAIRS CATEGORY ===
  TrainingQuestion(
    id: 'tech_010',
    category: 'Repairs',
    question: 'What is the purpose of a chimney liner?',
    options: [
      'To make the chimney look better',
      'To protect the chimney structure and improve draft',
      'To reduce heating costs',
      'To prevent animals from entering',
    ],
    correctIndex: 1,
    explanation: 'Liners protect the masonry from corrosive combustion gases, improve draft efficiency, and properly size the flue for the appliance.',
  ),
  TrainingQuestion(
    id: 'tech_011',
    category: 'Repairs',
    question: 'What is the minimum clearance required between a single-wall connector and combustible materials?',
    options: [
      '6 inches',
      '12 inches',
      '18 inches',
      '24 inches',
    ],
    correctIndex: 2,
    explanation: 'Single-wall connectors require a minimum 18-inch clearance to combustibles per NFPA codes.',
  ),
  TrainingQuestion(
    id: 'tech_012',
    category: 'Repairs',
    question: 'What is the correct mortar mix ratio for chimney crown repair?',
    options: [
      '1 part cement to 1 part sand',
      '1 part cement to 2 parts sand',
      '1 part cement to 3 parts sand',
      '1 part cement to 4 parts sand',
    ],
    correctIndex: 2,
    explanation: 'A 1:3 ratio (cement to sand) provides the proper strength and workability for chimney crown repairs.',
  ),

  // === CUSTOMER SERVICE CATEGORY ===
  TrainingQuestion(
    id: 'tech_013',
    category: 'Customer Service',
    question: 'What should you do if you discover a significant safety issue during a routine cleaning?',
    options: [
      'Complete the cleaning and mention it at the end',
      'Stop work, document the issue, and immediately inform the customer',
      'Fix it without telling the customer',
      'Complete the cleaning and send an email later',
    ],
    correctIndex: 1,
    explanation: 'Safety issues must be communicated immediately. Stop work, document thoroughly with photos, and explain the situation clearly to the customer.',
  ),
  TrainingQuestion(
    id: 'tech_014',
    category: 'Customer Service',
    question: 'How should you handle a customer complaint about a previous technician\'s work?',
    options: [
      'Blame the previous technician',
      'Ignore the complaint and do your job',
      'Listen empathetically, document the concern, and escalate to management',
      'Offer a discount immediately',
    ],
    correctIndex: 2,
    explanation: 'Always listen, document, and escalate complaints appropriately. Never blame colleagues or make promises without authorization.',
  ),
  TrainingQuestion(
    id: 'tech_015',
    category: 'Customer Service',
    question: 'Before leaving a job site, you should always:',
    options: [
      'Leave immediately to get to the next job',
      'Walk through the work with the customer and ensure they sign off',
      'Send an invoice by email',
      'Take a photo for social media',
    ],
    correctIndex: 1,
    explanation: 'Always review the completed work with the customer, answer questions, and obtain proper sign-off before leaving.',
  ),

  // === EQUIPMENT CATEGORY ===
  TrainingQuestion(
    id: 'tech_016',
    category: 'Equipment',
    question: 'How often should chimney brushes be inspected for wear?',
    options: [
      'Once a year',
      'Once a month',
      'Before each use',
      'Only when they look damaged',
    ],
    correctIndex: 2,
    explanation: 'Brushes should be inspected before each use to ensure they are effective and won\'t cause damage.',
  ),
  TrainingQuestion(
    id: 'tech_017',
    category: 'Equipment',
    question: 'What is the proper way to store extension rods?',
    options: [
      'Loosely in the truck bed',
      'Hung vertically or laid flat in a protective case',
      'In a pile in the corner',
      'Standing upright against a wall',
    ],
    correctIndex: 1,
    explanation: 'Rods should be stored properly to prevent bending, warping, or damage that could affect their performance.',
  ),
  TrainingQuestion(
    id: 'tech_018',
    category: 'Equipment',
    question: 'Which PPE is required when cleaning chimneys?',
    options: [
      'Safety glasses only',
      'Gloves only',
      'Respirator, safety glasses, gloves, and appropriate clothing',
      'Hard hat only',
    ],
    correctIndex: 2,
    explanation: 'Full PPE including N95/P100 respirator, safety glasses, work gloves, and protective clothing is required when cleaning chimneys.',
  ),

  // === CODES AND STANDARDS CATEGORY ===
  TrainingQuestion(
    id: 'tech_019',
    category: 'Codes',
    question: 'What organization publishes the primary chimney safety standards in the US?',
    options: [
      'EPA',
      'OSHA',
      'NFPA (National Fire Protection Association)',
      'FDA',
    ],
    correctIndex: 2,
    explanation: 'NFPA publishes standards including NFPA 211 which covers chimneys, fireplaces, vents, and solid fuel-burning appliances.',
  ),
  TrainingQuestion(
    id: 'tech_020',
    category: 'Codes',
    question: 'According to NFPA 211, how high should a chimney extend above the roof?',
    options: [
      '2 feet above any point within 10 feet',
      '3 feet above roof penetration and 2 feet above anything within 10 feet',
      '4 feet above the roof at all points',
      '1 foot above the highest point of the roof',
    ],
    correctIndex: 1,
    explanation: 'The 3-2-10 rule: chimney must be 3 feet above roof penetration and 2 feet higher than anything within 10 feet horizontally.',
  ),

  // Add more placeholder questions below as needed
  // Copy the pattern above and update id, category, question, options, correctIndex, and explanation
];

/// ============================================================================
/// DISPATCHER QUESTIONS
/// ============================================================================
/// 
/// Final Exam - Dispatcher & Chimney Knowledge
/// 39 Questions Total

const List<TrainingQuestion> _dispatcherQuestions = [
  // === PHONE HANDLING ===
  TrainingQuestion(
    id: 'disp_001',
    category: 'Phone Handling',
    question: 'What is the maximum time allowed to answer the phone during business hours?',
    options: [
      '5 seconds',
      '10 seconds',
      '15 seconds',
      '20 seconds',
    ],
    correctIndex: 1,
    explanation: 'Phones must be answered within 10 seconds to provide excellent customer service.',
  ),
  TrainingQuestion(
    id: 'disp_002',
    category: 'Phone Handling',
    question: 'Why is it important to convert every call into a client?',
    options: [
      'To avoid long call queues',
      'Because each call may cost the company money',
      'To reduce workload for technicians',
      'To fill the schedule faster only',
    ],
    correctIndex: 1,
    explanation: 'Marketing costs money per lead. Every call represents an investment that should be converted into revenue.',
  ),
  TrainingQuestion(
    id: 'disp_003',
    category: 'Phone Handling',
    question: 'What is the ideal maximum call length?',
    options: [
      '2 minutes',
      '3.5 minutes',
      '4 minutes',
      '5 minutes',
    ],
    correctIndex: 1,
    explanation: 'Calls should be efficient at around 3.5 minutes to handle volume while still providing quality service.',
  ),
  TrainingQuestion(
    id: 'disp_004',
    category: 'Dispatcher Requirements',
    question: 'Which of the following is NOT a Dispatcher Requirement?',
    options: [
      'Clock in and out (office-based)',
      'Send a good morning message if home-based',
      'Always give discounts without approval',
      'Work in a quiet environment',
    ],
    correctIndex: 2,
    explanation: 'Discounts require approval. Dispatchers should never give discounts without proper authorization.',
  ),
  TrainingQuestion(
    id: 'disp_005',
    category: 'Phone Handling',
    question: 'If a client asks something you don\'t know, what should you do?',
    options: [
      'Guess the answer confidently',
      'Put them on hold and ask your supervisor',
      'Tell them you\'ll call back next week',
      'Transfer them immediately to another department without explanation',
    ],
    correctIndex: 1,
    explanation: 'When unsure, put the customer on hold briefly and ask your supervisor for the correct information.',
  ),
  TrainingQuestion(
    id: 'disp_006',
    category: 'Dispatcher Requirements',
    question: 'Why must you know the area you\'re working on?',
    options: [
      'To provide accurate scheduling and logistics',
      'To improve sales scripts',
      'To decide technician pay rates',
      'To change job sources',
    ],
    correctIndex: 0,
    explanation: 'Knowing your service area helps with accurate scheduling, travel time estimates, and logistics.',
  ),
  TrainingQuestion(
    id: 'disp_007',
    category: 'Dispatcher Requirements',
    question: 'If working from home, how do you confirm you\'re ready for your shift?',
    options: [
      'By calling your supervisor',
      'By sending a "good morning" in the WhatsApp group',
      'By logging into RingCentral only',
      'By sending an email',
    ],
    correctIndex: 1,
    explanation: 'Home-based dispatchers must send a good morning message in the WhatsApp group to confirm they are ready.',
  ),
  TrainingQuestion(
    id: 'disp_008',
    category: 'Job Sources',
    question: 'Which job source example below shows the correct way to identify a lead?',
    options: [
      '"SEO - Cleveland"',
      '"Cleveland - SEO - (216) 543-4505"',
      '"SEO Lead - Call Now"',
      '"Google Lead - Cleveland"',
    ],
    correctIndex: 1,
    explanation: 'The correct format includes: Area - Source - Phone Number (e.g., "Cleveland - SEO - (216) 543-4505").',
  ),

  // === CUSTOMER INTERACTION ===
  TrainingQuestion(
    id: 'disp_009',
    category: 'Customer Interaction',
    question: 'What is the first question after greeting a customer?',
    options: [
      '"What time works best for you?"',
      '"May I have your address to see if we serve your area?"',
      '"Can you pay today?"',
      '"Do you want same-day service?"',
    ],
    correctIndex: 1,
    explanation: 'Always verify the service area first by asking for their address.',
  ),
  TrainingQuestion(
    id: 'disp_010',
    category: 'Customer Interaction',
    question: 'If the customer says, "I think I\'ll hold off for now," what is the first step?',
    options: [
      'Offer a free inspection immediately',
      'Ask what is holding them back (availability, pricing, etc.)',
      'Hang up politely',
      'Offer a discount only if they complain',
    ],
    correctIndex: 1,
    explanation: 'Understand their hesitation first by asking what is holding them back before offering solutions.',
  ),
  TrainingQuestion(
    id: 'disp_011',
    category: 'Pricing',
    question: 'What is the standard inspection fee before offering discounts?',
    options: [
      '\$49',
      '\$99',
      '\$149',
      'Free',
    ],
    correctIndex: 1,
    explanation: 'The standard inspection fee is \$99 before any applicable discounts.',
  ),

  // === COMPLAINT HANDLING ===
  TrainingQuestion(
    id: 'disp_012',
    category: 'Complaint Handling',
    question: 'In the complaint call script, what is the MOST important thing while the client speaks?',
    options: [
      'Take notes and interrupt for clarification',
      'Let them speak without interrupting',
      'Offer discounts',
      'Transfer the call right away',
    ],
    correctIndex: 1,
    explanation: 'Let the customer vent and speak without interrupting. Active listening is crucial for complaint resolution.',
  ),
  TrainingQuestion(
    id: 'disp_013',
    category: 'Complaint Handling',
    question: 'After ending a complaint call, what should you do?',
    options: [
      'Wait for the customer to call back',
      'Send the complaint to the WhatsApp group and tag the area manager',
      'Schedule a free service automatically',
      'Offer an upgrade service',
    ],
    correctIndex: 1,
    explanation: 'Document the complaint in the WhatsApp group and tag the area manager for follow-up.',
  ),

  // === ETA CALLS ===
  TrainingQuestion(
    id: 'disp_014',
    category: 'ETA Calls',
    question: 'If you\'re calling a customer for ETA confirmation, what should you do first?',
    options: [
      'Match your caller ID to the customer\'s area code',
      'Call immediately without checking caller ID',
      'Send a text first',
      'Call from the company main number only',
    ],
    correctIndex: 0,
    explanation: 'Match your caller ID to the customer\'s area code so they recognize the call as local.',
  ),
  TrainingQuestion(
    id: 'disp_015',
    category: 'ETA Calls',
    question: 'If no answer on an ETA call, what is the next step?',
    options: [
      'Reschedule the job',
      'Text the customer to call back and mention the appointment',
      'Cancel the job',
      'Inform the technician without texting the customer',
    ],
    correctIndex: 1,
    explanation: 'If no answer, text the customer asking them to call back and reference their appointment.',
  ),
  TrainingQuestion(
    id: 'disp_016',
    category: 'ETA Calls',
    question: 'In the ETA call protocol, what exact message should you send the technician?',
    options: [
      '"Client called for ETA. Please call ASAP."',
      '"Where are you?"',
      '"Call me back."',
      '"Customer is waiting."',
    ],
    correctIndex: 0,
    explanation: 'Use the standard message: "Client called for ETA. Please call ASAP."',
  ),

  // === WORKIZ/JOB MANAGEMENT ===
  TrainingQuestion(
    id: 'disp_017',
    category: 'Workiz',
    question: 'Before creating a job in Workiz, what must you confirm?',
    options: [
      'The correct Workiz account is selected',
      'The technician is available immediately',
      'The client can pay cash only',
      'That the job is commercial only',
    ],
    correctIndex: 0,
    explanation: 'Always verify you\'re in the correct Workiz account before creating any job.',
  ),
  TrainingQuestion(
    id: 'disp_018',
    category: 'Workiz',
    question: 'If a job is "In Progress" and needs rescheduling, what must you do after rescheduling?',
    options: [
      'Leave it as "In Progress"',
      'Change status back to "Submitted" and notify the office manager',
      'Cancel the job',
      'Assign it to another technician automatically',
    ],
    correctIndex: 1,
    explanation: 'Change the status back to "Submitted" and notify the office manager when rescheduling an in-progress job.',
  ),
  TrainingQuestion(
    id: 'disp_019',
    category: 'Workiz',
    question: 'If a DPA (Done Pending Approval) job needs scheduling, what must you do?',
    options: [
      'Schedule it immediately',
      'Get area manager approval first',
      'Cancel the job',
      'Assign it to any available technician',
    ],
    correctIndex: 1,
    explanation: 'DPA jobs require area manager approval before scheduling.',
  ),
  TrainingQuestion(
    id: 'disp_020',
    category: 'Job Management',
    question: 'When a customer cancels a job, what two steps must you take?',
    options: [
      'Delete the job and tell the tech',
      'Add detailed notes and notify the area manager',
      'Call the technician only',
      'Mark the job "Closed"',
    ],
    correctIndex: 1,
    explanation: 'Add detailed cancellation notes and notify the area manager.',
  ),
  TrainingQuestion(
    id: 'disp_021',
    category: 'Job Management',
    question: 'If calling to make an appointment for someone else, what must you collect?',
    options: [
      'Only the payer\'s name',
      'Full name and number for both booking person and onsite person',
      'Technician\'s phone number',
      'Supervisor approval',
    ],
    correctIndex: 1,
    explanation: 'Collect full name and phone number for both the person booking and the person who will be onsite.',
  ),
  TrainingQuestion(
    id: 'disp_022',
    category: 'Job Management',
    question: 'In the job description for a tenant/realtor appointment, what must you specify?',
    options: [
      'Only the name of the tenant',
      'Who is who, and who to contact for access',
      'Only the realtor\'s phone number',
      'Only the address',
    ],
    correctIndex: 1,
    explanation: 'Clearly specify who is who (tenant, realtor, owner) and who to contact for property access.',
  ),
  TrainingQuestion(
    id: 'disp_023',
    category: 'Job Management',
    question: 'If a customer wants to reschedule a "Submitted" job, what do you do?',
    options: [
      'Reschedule based on area availability and add notes',
      'Cancel the job and create a new one',
      'Ask the manager for every change',
      'Wait for the tech to call',
    ],
    correctIndex: 0,
    explanation: 'Reschedule based on area availability and add notes documenting the change.',
  ),
  TrainingQuestion(
    id: 'disp_024',
    category: 'Workiz',
    question: 'When entering the client\'s phone number in Workiz, where else should you put it?',
    options: [
      'In the "Job Description" field',
      'In the technician notes',
      'In the WhatsApp group',
      'In the area manager\'s email',
    ],
    correctIndex: 0,
    explanation: 'Always duplicate the phone number in the Job Description field for easy access.',
  ),

  // === CHIMNEY KNOWLEDGE ===
  TrainingQuestion(
    id: 'disp_025',
    category: 'Chimney Knowledge',
    question: 'How often should all chimneys, fireplaces, and vents be inspected per NFPA 211?',
    options: [
      'Twice a year',
      'Once a year',
      'Every 5 years',
      'Every 2 years',
    ],
    correctIndex: 1,
    explanation: 'NFPA 211 recommends annual inspection of all chimneys, fireplaces, and venting systems.',
  ),
  TrainingQuestion(
    id: 'disp_026',
    category: 'Chimney Knowledge',
    question: 'At what creosote buildup thickness should a chimney be cleaned?',
    options: [
      '1/4 inch',
      '1/8 inch',
      '1/16 inch',
      '1/2 inch',
    ],
    correctIndex: 1,
    explanation: 'Chimneys should be cleaned when creosote buildup reaches 1/8 inch thickness.',
  ),
  TrainingQuestion(
    id: 'disp_027',
    category: 'Chimney Knowledge',
    question: 'Which inspection involves removing parts of the chimney or building?',
    options: [
      'Level 1',
      'Level 2',
      'Level 3',
      'None',
    ],
    correctIndex: 2,
    explanation: 'Level 3 inspections may require removal of chimney or building components to access hidden areas.',
  ),
  TrainingQuestion(
    id: 'disp_028',
    category: 'Chimney Knowledge',
    question: 'Which fireplace type is pre-constructed from metal and installed in homes?',
    options: [
      'Masonry fireplace',
      'Furnace',
      'Factory-built fireplace',
      'Wood stove',
    ],
    correctIndex: 2,
    explanation: 'Factory-built (prefabricated) fireplaces are pre-constructed metal units installed in homes.',
  ),
  TrainingQuestion(
    id: 'disp_029',
    category: 'Chimney Knowledge',
    question: 'What is the main purpose of a chimney crown?',
    options: [
      'Add height',
      'Prevent water and debris from entering the chimney',
      'Hold the chimney cap in place',
      'Support the flue liner',
    ],
    correctIndex: 1,
    explanation: 'The chimney crown prevents water and debris from entering the chimney structure.',
  ),
  TrainingQuestion(
    id: 'disp_030',
    category: 'Chimney Knowledge',
    question: 'Which component prevents embers from escaping the chimney?',
    options: [
      'Crown',
      'Damper',
      'Spark arrestor',
      'Flashing',
    ],
    correctIndex: 2,
    explanation: 'The spark arrestor is mesh screening that prevents embers from escaping and causing fires.',
  ),
  TrainingQuestion(
    id: 'disp_031',
    category: 'Chimney Knowledge',
    question: 'What does a thermocouple do in a gas fireplace?',
    options: [
      'Controls airflow',
      'Shuts off gas if the pilot light goes out',
      'Increases draft',
      'Reduces soot buildup',
    ],
    correctIndex: 1,
    explanation: 'The thermocouple is a safety device that shuts off gas flow if the pilot light goes out.',
  ),
  TrainingQuestion(
    id: 'disp_032',
    category: 'Chimney Knowledge',
    question: 'What is the purpose of a chimney cricket?',
    options: [
      'Hold the crown in place',
      'Divert water away from the chimney',
      'Prevent smoke from backing up',
      'Increase draft',
    ],
    correctIndex: 1,
    explanation: 'A chimney cricket (saddle) diverts water away from the chimney on the roof.',
  ),

  // === PRICING & SERVICES ===
  TrainingQuestion(
    id: 'disp_033',
    category: 'Pricing',
    question: 'What is the cost of the annual maintenance program?',
    options: [
      '\$120/year',
      '\$240/year',
      '\$300/year',
      '\$500/year',
    ],
    correctIndex: 1,
    explanation: 'The annual maintenance program costs \$240/year.',
  ),
  TrainingQuestion(
    id: 'disp_034',
    category: 'Chimney Knowledge',
    question: 'Which inspections may involve drone use?',
    options: [
      'Level 1 and Level 2',
      'Level 2 and Level 3',
      'Only Level 3',
      'All levels',
    ],
    correctIndex: 1,
    explanation: 'Drones may be used for Level 2 and Level 3 inspections to access difficult areas.',
  ),
  TrainingQuestion(
    id: 'disp_035',
    category: 'Pricing',
    question: 'What discount is offered to veterans and senior citizens?',
    options: [
      '5%',
      '10%',
      '15%',
      '20%',
    ],
    correctIndex: 1,
    explanation: 'Veterans and senior citizens receive a 10% discount.',
  ),
  TrainingQuestion(
    id: 'disp_036',
    category: 'Company Info',
    question: 'Are A1 Chimney technicians certified?',
    options: [
      'Yes, CSIA certified',
      'No',
      'Only managers are certified',
      'Only some states require it',
    ],
    correctIndex: 0,
    explanation: 'A1 Chimney technicians are CSIA (Chimney Safety Institute of America) certified.',
  ),
  TrainingQuestion(
    id: 'disp_037',
    category: 'Pricing',
    question: 'What financing option may be available?',
    options: [
      '0% APR depending on credit',
      'Interest-only loans',
      'Cash-only discounts',
      '12% fixed APR',
    ],
    correctIndex: 0,
    explanation: '0% APR financing may be available depending on the customer\'s credit.',
  ),
  TrainingQuestion(
    id: 'disp_038',
    category: 'Customer Interaction',
    question: 'Is someone required to be home during an inspection?',
    options: [
      'Always required',
      'Only for Level 3 inspections',
      'Preferred but not mandatory',
      'Only if it\'s a first-time customer',
    ],
    correctIndex: 2,
    explanation: 'It is preferred that someone is home but not mandatory for inspections.',
  ),

  // === COMPLAINT PROCESS ===
  TrainingQuestion(
    id: 'disp_039',
    category: 'Complaint Handling',
    question: 'What is the first step when a customer calls with a complaint?',
    options: [
      'Add notes in WhatsApp',
      'Pull up the job by job number in the "search everything" bar',
      'Call the technician immediately',
      'Offer a discount',
    ],
    correctIndex: 1,
    explanation: 'First, pull up the job using the job number in the "search everything" bar to have context.',
  ),
  TrainingQuestion(
    id: 'disp_040',
    category: 'Complaint Handling',
    question: 'After adding a complaint to the notes, what is the very next step?',
    options: [
      'Notify the technician',
      'Save the notes',
      'Call the customer back',
      'Copy the job number',
    ],
    correctIndex: 1,
    explanation: 'Always save the notes immediately after adding them to prevent data loss.',
  ),
];

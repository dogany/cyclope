// Landing copy for both supported languages. Ported from the original static
// site so the Svelte version stays in sync with the existing wording.

/** @typedef {'en' | 'ko'} Language */

export const LANGUAGES = /** @type {const} */ (['en', 'ko']);

export const translations = {
	en: {
		lang: 'en',
		title: 'Cyclope',
		description: 'All-in-one control for windows, sleep, and scroll direction on Mac.',
		heroTagline: 'All-in-One Mac Control',
		seeApp: 'See The App',
		readPrivacy: 'Read Privacy',
		downloadMac: 'Download for Mac',
		versionLabel: 'Version',
		downloadNote: 'Free · macOS 15+ · Apple Silicon & Intel',
		releaseNotes: 'Release notes',
		featureWindowTitle: 'Window Management',
		featureWindowCopy: 'Move, snap, center, or use custom layouts.',
		featureSleepTitle: 'Sleep Prevention',
		featureSleepCopy: 'Keep your Mac awake when work needs time.',
		featureScrollTitle: 'Scroll Direction Control',
		featureScrollCopy: 'Switch scroll behavior for mouse, trackpad, and external setups.',
		showcaseMenuTitle: 'One menu. Everyday control.',
		showcaseMenuCopy: 'Window, sleep, and scroll controls stay one click away.',
		showcaseMenuPointOne: 'Show only the sections you use',
		showcaseMenuPointTwo: 'Reorder the menu your way',
		showcaseMenuAlt: 'Cyclope menu bar controls next to Menu Sections preferences',
		showcaseWindowTitle: 'Windows, handled fast.',
		showcaseWindowCopy: 'Snap positions and custom layouts are ready from menus, shortcuts, or the command sheet.',
		showcaseWindowPointOne: 'Left, right, top, bottom, full screen, and center',
		showcaseWindowPointTwo: 'Custom layouts and shortcuts',
		showcaseWindowAlt: 'Cyclope Window settings showing snap commands and shortcuts',
		showcaseModalTitle: 'Keyboard first. No friction.',
		showcaseModalCopy: 'Open the command sheet, press a key, and keep moving.',
		showcaseModalPointOne: 'Fast snap commands',
		showcaseModalPointTwo: 'Small nudges without leaving the keyboard',
		showcaseModalAlt: 'Cyclope Command Modal showing window snap shortcuts',
		showcaseSleepTitle: 'Keep the Mac awake.',
		showcaseSleepCopy: 'Set a duration, add battery rules, and toggle it instantly.',
		showcaseSleepPointOne: 'Quick durations and defaults',
		showcaseSleepPointTwo: 'Battery-aware control',
		showcaseSleepAlt: 'Cyclope settings showing Sleep Prevention controls',
		privacyPolicy: 'Privacy Policy',
		backHome: 'Back to home'
	},
	ko: {
		lang: 'ko',
		title: 'Cyclope',
		description: 'Mac의 창, 잠자기, 스크롤 방향을 한곳에서 제어합니다.',
		heroTagline: 'All-in-One Mac Control',
		seeApp: '앱 보기',
		readPrivacy: '개인정보처리방침',
		downloadMac: 'Mac용 다운로드',
		versionLabel: '버전',
		downloadNote: '무료 · macOS 15+ · Apple Silicon & Intel',
		releaseNotes: '릴리스 노트',
		featureWindowTitle: 'Window Management',
		featureWindowCopy: '창을 빠르게 이동하고, 스냅하고, 커스텀 레이아웃으로 정리합니다.',
		featureSleepTitle: 'Sleep Prevention',
		featureSleepCopy: '작업이 끝날 때까지 Mac을 깨어 있게 유지합니다.',
		featureScrollTitle: 'Scroll Direction Control',
		featureScrollCopy: '마우스, 트랙패드, 외부 장비에 맞춰 스크롤 방향을 전환합니다.',
		showcaseMenuTitle: '하나의 메뉴. 매일 쓰는 제어.',
		showcaseMenuCopy: '창, 잠자기, 스크롤 제어를 클릭 한 번 거리에 둡니다.',
		showcaseMenuPointOne: '쓰는 섹션만 표시',
		showcaseMenuPointTwo: '원하는 순서로 메뉴 정리',
		showcaseMenuAlt: 'Menu Sections 설정과 함께 보이는 Cyclope 메뉴 막대 제어',
		showcaseWindowTitle: '창 관리를 더 빠르게.',
		showcaseWindowCopy: '메뉴, 단축키, 명령 시트에서 스냅 위치와 커스텀 레이아웃을 바로 실행합니다.',
		showcaseWindowPointOne: '왼쪽, 오른쪽, 위, 아래, 전체 화면, 중앙',
		showcaseWindowPointTwo: '커스텀 레이아웃과 단축키',
		showcaseWindowAlt: '창 배치 명령과 단축키를 보여주는 Cyclope Window 설정 화면',
		showcaseModalTitle: '키보드 중심. 마찰 없이.',
		showcaseModalCopy: '명령 시트를 열고 키 하나로 바로 실행합니다.',
		showcaseModalPointOne: '빠른 창 스냅',
		showcaseModalPointTwo: '키보드에서 바로 미세 이동',
		showcaseModalAlt: '창 배치 단축키를 보여주는 Cyclope Command Modal',
		showcaseSleepTitle: 'Mac을 깨어 있게.',
		showcaseSleepCopy: '유지 시간을 정하고, 배터리 조건을 넣고, 필요할 때 즉시 켭니다.',
		showcaseSleepPointOne: '빠른 시간 선택과 기본값',
		showcaseSleepPointTwo: '배터리 조건 제어',
		showcaseSleepAlt: 'Sleep Prevention 설정을 보여주는 Cyclope 화면',
		privacyPolicy: '개인정보처리방침',
		backHome: '홈으로'
	}
};

/**
 * Resolve the copy table for a language, falling back to English.
 * @param {string} language
 * @returns {Record<string, string>}
 */
export function copyFor(language) {
	return translations[/** @type {Language} */ (language)] ?? translations.en;
}

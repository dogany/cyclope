// Landing copy for both supported languages. Ported from the original static
// site so the Svelte version stays in sync with the existing wording.

/** @typedef {'en' | 'ko'} Language */

export const LANGUAGES = /** @type {const} */ (['en', 'ko']);

export const translations = {
	en: {
		lang: 'en',
		title: 'Cyclope',
		description:
			'Cyclope puts window management, sleep prevention, and scroll direction control in one Mac menu bar app.',
		heroTagline: 'All-in-One Mac Control',
		seeApp: 'See The App',
		readPrivacy: 'Read Privacy',
		downloadMac: 'Download for Mac',
		versionLabel: 'Version',
		downloadNote: 'Free · macOS 15+ · Apple Silicon & Intel',
		releaseNotes: 'Release notes',
		sectionEyebrow: 'Core Features',
		sectionTitle: 'Window Manager.<br>Sleep Prevent.<br>Scroll Reverse.',
		sectionLede:
			'Cyclope keeps the Mac controls you use every day in one place: move windows, keep your Mac awake, and switch scroll direction from the menu bar.',
		featureWindowTitle: 'Window Manager',
		featureWindowCopy:
			'Move the active window to halves, thirds, full screen, center, or custom layouts.',
		featureSleepTitle: 'Sleep Prevent',
		featureSleepCopy: 'Keep your Mac awake for a set time, or keep it awake until you turn it off.',
		featureScrollTitle: 'Scroll Reverse',
		featureScrollCopy:
			'Switch scroll direction quickly when you move between a trackpad, mouse, or external setup.',
		showcaseMenuTitle: 'Menu bar controls, section by section.',
		showcaseMenuCopy:
			'Open Cyclope from the menu bar for quick window moves and Sleep Prevent. Use Preferences to choose which sections stay visible.',
		showcaseMenuPointOne: 'Window and Sleep controls stay one click away',
		showcaseMenuPointTwo: 'Menu sections can be shown, hidden, and reordered',
		showcaseMenuAlt: 'Cyclope menu bar controls next to Menu Sections preferences',
		showcaseWindowTitle: 'Window commands with shortcuts you can see.',
		showcaseWindowCopy:
			'The Window settings screen lists each snap command with its modal key and global shortcut, so your layout controls stay predictable.',
		showcaseWindowPointOne: 'Left, right, top, bottom, full screen, and center commands',
		showcaseWindowPointTwo: 'Modal keys and global shortcuts in the same view',
		showcaseWindowAlt: 'Cyclope Window settings showing snap commands and shortcuts',
		showcaseModalTitle: 'Command Modal for keyboard-first control.',
		showcaseModalCopy:
			'Open the modal, press a key to snap, or use arrow keys to nudge the current window slightly without leaving the keyboard.',
		showcaseModalPointOne: 'Compact command sheet for snap positions and custom layouts',
		showcaseModalPointTwo: 'Arrow keys nudge; Command + Arrow snaps',
		showcaseModalAlt: 'Cyclope Command Modal showing window snap shortcuts',
		showcaseSleepTitle: 'Sleep settings that match long-running work.',
		showcaseSleepCopy:
			'Set the default Sleep Prevent duration, add battery rules, and assign a global shortcut for quick activation.',
		showcaseSleepPointOne: 'Default duration and battery behavior in one panel',
		showcaseSleepPointTwo: 'Optional global shortcut for Sleep Prevent',
		showcaseSleepAlt: 'Cyclope settings showing Sleep Prevent controls',
		privacyPolicy: 'Privacy Policy',
		backHome: 'Back to home'
	},
	ko: {
		lang: 'ko',
		title: 'Cyclope',
		description:
			'Cyclope는 창 관리, 잠자기 방지, 스크롤 방향 전환을 메뉴 막대 하나에 모은 Mac 유틸리티입니다.',
		heroTagline: 'All-in-One Mac Control',
		seeApp: '앱 보기',
		readPrivacy: '개인정보처리방침',
		downloadMac: 'Mac용 다운로드',
		versionLabel: '버전',
		downloadNote: '무료 · macOS 15+ · Apple Silicon & Intel',
		releaseNotes: '릴리스 노트',
		sectionEyebrow: '주요 기능',
		sectionTitle: 'Window Manager.<br>Sleep Prevent.<br>Scroll Reverse.',
		sectionLede:
			'매일 쓰는 Mac 제어만 한곳에 모았습니다. 창을 정리하고, Mac을 깨어 있게 유지하고, 스크롤 방향을 메뉴 막대에서 바로 바꿉니다.',
		featureWindowTitle: 'Window Manager',
		featureWindowCopy: '현재 창을 반쪽, 3분할, 전체 화면, 중앙, 커스텀 레이아웃으로 이동합니다.',
		featureSleepTitle: 'Sleep Prevent',
		featureSleepCopy: '정해진 시간 동안, 또는 끌 때까지 Mac을 깨어 있게 유지합니다.',
		featureScrollTitle: 'Scroll Reverse',
		featureScrollCopy: '트랙패드, 마우스, 외부 장비를 오갈 때 스크롤 방향을 빠르게 전환합니다.',
		showcaseMenuTitle: '메뉴 막대에서 필요한 제어만.',
		showcaseMenuCopy:
			'메뉴 막대에서 Cyclope를 열어 창 이동과 Sleep Prevent를 바로 실행합니다. Preferences에서 보일 섹션도 직접 정할 수 있습니다.',
		showcaseMenuPointOne: 'Window와 Sleep 제어를 한 번에 실행',
		showcaseMenuPointTwo: '메뉴 섹션 표시, 숨김, 순서 변경 지원',
		showcaseMenuAlt: 'Menu Sections 설정과 함께 보이는 Cyclope 메뉴 막대 제어',
		showcaseWindowTitle: '단축키가 바로 보이는 Window 설정.',
		showcaseWindowCopy:
			'각 창 배치 명령의 모달 키와 글로벌 단축키를 한 화면에서 확인하고 설정할 수 있습니다.',
		showcaseWindowPointOne: '왼쪽, 오른쪽, 위, 아래, 전체 화면, 중앙 배치',
		showcaseWindowPointTwo: '모달 키와 글로벌 단축키를 같은 화면에서 관리',
		showcaseWindowAlt: '창 배치 명령과 단축키를 보여주는 Cyclope Window 설정 화면',
		showcaseModalTitle: '키보드로 바로 쓰는 Command Modal.',
		showcaseModalCopy:
			'모달을 열고 키 하나로 창을 배치합니다. 화살표 키로는 현재 창을 조금씩 이동할 수 있습니다.',
		showcaseModalPointOne: '기본 배치와 커스텀 레이아웃을 한 화면에 표시',
		showcaseModalPointTwo: '화살표 키는 미세 이동, Command + 화살표는 스냅',
		showcaseModalAlt: '창 배치 단축키를 보여주는 Cyclope Command Modal',
		showcaseSleepTitle: '긴 작업에 맞춘 Sleep 설정.',
		showcaseSleepCopy:
			'기본 유지 시간, 배터리 조건, 글로벌 단축키를 한 화면에서 설정해 긴 작업 중 Mac이 잠들지 않게 유지합니다.',
		showcaseSleepPointOne: '기본 유지 시간과 배터리 동작을 한곳에서 설정',
		showcaseSleepPointTwo: 'Sleep Prevent용 글로벌 단축키 지원',
		showcaseSleepAlt: 'Sleep Prevent 설정을 보여주는 Cyclope 화면',
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

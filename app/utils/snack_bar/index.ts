// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.
import {Screens} from '@constants';
import {SNACK_BAR_TYPE} from '@constants/snack_bar';
import {showOverlay} from '@screens/navigation';

import type {AvailableScreens} from '@typings/screens/navigation';

type AddChannelMemberValues = {
    numMembers: number;
};

export type ShowSnackBarArgs = {
    barType: keyof typeof SNACK_BAR_TYPE;
    onAction?: () => void;
    sourceScreen?: AvailableScreens;
    messageValues?: AddChannelMemberValues | {};

};

export const showSnackBar = (passProps: ShowSnackBarArgs) => {
    const screen = Screens.SNACK_BAR;
    showOverlay(screen, passProps);
};

export const showMuteChannelSnackbar = (muted: boolean, onAction: () => void) => {
    return showSnackBar({
        onAction,
        barType: muted ? SNACK_BAR_TYPE.MUTE_CHANNEL : SNACK_BAR_TYPE.UNMUTE_CHANNEL,
    });
};

export const showFavoriteChannelSnackbar = (favorited: boolean, onAction: () => void) => {
    return showSnackBar({
        onAction,
        barType: favorited ? SNACK_BAR_TYPE.FAVORITE_CHANNEL : SNACK_BAR_TYPE.UNFAVORITE_CHANNEL,
    });
};

export const showAddChannelMembersSnackbar = (ids: string[]) => {
    return showSnackBar({
        barType: SNACK_BAR_TYPE.ADD_CHANNEL_MEMBERS,
        sourceScreen: Screens.CHANNEL_ADD_PEOPLE,
        messageValues: {numMembers: ids.length},
    });
};

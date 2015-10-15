import QtQuick 2.0
import Ubuntu.Components 1.3
import Ubuntu.Content 1.1
import QtGraphicalEffects 1.0

Page {
    id: chatPage
    title: conv_name || "Chat"
    visible: false

    property string conv_name
    property string conv_id
    property string status_message: ""
    property bool first_message_loaded: false
    property bool loaded: false

    property alias listView: listView
    property alias pullToRefresh: pullToRefresh

    property bool initialMessagesLoaded: false
    property bool pullToRefreshLoading: false

    flickable: listView

    onVisibleChanged: {
        if (!visible) {
            pullToRefreshLoading = false;
            py.call('backend.left_conversation', [conv_id]);
        }
        else {
            //listView.positionViewAtEnd();
            if (!loaded) {
                py.call('backend.load_conversation', [conv_id])
            }
        }
    }

    head.actions: [
        Action {
            iconName: "info"
            text: i18n.tr("Info")
            onTriggered: pageLayout.addPageToNextColumn(chatPage, aboutConversationPage, {mData: conversationsModel.get(getConversationModelIndexById(conv_id))})
        },
        Action {
            iconName: "add"
            text: i18n.tr("Add")
            onTriggered: {
                var user_ids = [];
                var users = conversationsModel.get(getConversationModelIndexById(conv_id)).users;
                for (var i=0; i<users.count; i++) {
                    user_ids.push(users.get(i).id_.toString());
                }
                pageLayout.addPageToNextColumn(chatPage, selectUsersPage, {headTitle: i18n.tr("Add users"), excludedUsers: user_ids, callback: function onUsersSelected(users){
                    py.call('backend.add_users', [conv_id, users]);
                }});
            }
        }
    ]

    head.contents: Item {
        height: units.gu(5)
        width: parent ? parent.width - units.gu(2) : undefined
        Label {
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            text: title
            fontSize: "x-large"
            elide: Text.ElideRight
            visible: status_message == ""
        }

        Label {
            width: parent.width
            anchors.top: parent.top
            text: title
            fontSize: "large"
            elide: Text.ElideRight
            visible: status_message != ""
        }

        Label {
            width: parent.width
            opacity: status_message != "" ? 1.0: 0
            color: UbuntuColors.green
            anchors.bottom: parent.bottom
            text: status_message
            elide: Text.ElideRight
            Behavior on opacity {
                NumberAnimation { duration: 500 }
            }
        }
    }

    Image {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomContainer.top
        source: Qt.resolvedUrl('../media/default_chat_wallpaper.jpg')

        UbuntuListView {
            id: listView

            anchors.fill: parent

            model: currentChatModel
            spacing: units.gu(1)
            delegate: ChatListItem {}

            header: Component {
                Item {
                    height: units.gu(5)
                    width: parent.width

                    ActivityIndicator {
                        running: !loaded
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            footer: Component {
                Item {
                    height: units.gu(5)
                    width: parent.width
                }
            }

            PullToRefresh {
                id: pullToRefresh
                width: parent.width

                enabled: !first_message_loaded

                content: Item {
                    height: parent.height
                    width: height

                    Label {
                        anchors.centerIn: parent
                        color: "white"
                        text: !pullToRefresh.releaseToRefresh ? i18n.tr("Pull to load more") : i18n.tr("Release to load more")
                    }

                }

                onRefresh: {
                    refreshing = true;
                    pullToRefreshLoading = true;
                    py.call('backend.load_more_messages', [conv_id]);
                }
            }

            UbuntuShape {
                id: btnScrollToBottom
                color: "black"
                property double maxOpacity: 0.5
                property double opacityFromViewPosition: ((1-(listView.visibleArea.yPosition + listView.visibleArea.heightRatio))*listView.contentHeight) / (listView.height)
                opacity: (opacityFromViewPosition < maxOpacity ? opacityFromViewPosition : maxOpacity)
                width: units.dp(48)
                height: width
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: units.gu(2)

                Icon {
                    anchors.centerIn: parent
                    width: units.dp(40)
                    height: width
                    name: "down"
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: listView.positionViewAtEnd();
                }
            }

        }

    }

    Rectangle {
        id: bottomContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        height: units.gu(6)

        color: "white"

        TextField {
            id: messageField

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.right: attachmentIcon.left
            anchors.bottom: parent.bottom
            anchors.margins: units.gu(1)

            placeholderText: i18n.tr("Write a message")

            onAccepted: {
                if (messageField.text !== "") {
                    py.call('backend.send_message', [conv_id, messageField.text]);
                    messageField.text = "";
                    py.call('backend.set_typing', [conv_id, "stopped"]);
                    pausedTypingTimer.stop();
                    stoppedTypingTimer.stop();
                }
            }

            Timer {
                id: pausedTypingTimer
                interval: 1500
                onTriggered: {
                    py.call('backend.set_typing', [conv_id, "paused"]);
                    stoppedTypingTimer.start();
                }
            }

            Timer {
                id: stoppedTypingTimer
                interval: 3000
                onTriggered: py.call('backend.set_typing', [conv_id, "stopped"]);
            }

            onTextChanged: {
                py.call('backend.set_typing', [conv_id, "typing"]);
                pausedTypingTimer.stop();
                stoppedTypingTimer.stop();
                pausedTypingTimer.start();
            }
        }

        Icon {
            id: attachmentIcon

            anchors.top: parent.top
            anchors.right: sendIcon.left
            anchors.bottom: parent.bottom
            anchors.margins: units.gu(1)
            anchors.rightMargin: units.gu(2)
            anchors.leftMargin: units.gu(2)

            name: 'insert-image'
            width: height
            height: parent.height - units.gu(1)

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    importContentPopup.show();
                }

            }

        }

        Image {
            id: sendIcon

            property bool send_icon_clicked: false

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: units.gu(1)
            anchors.rightMargin: units.gu(2)
            anchors.leftMargin: units.gu(2)

            source: Qt.resolvedUrl("../media/google-md-send-icon.svg")
            width: height
            height: parent.height - units.gu(1)

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    Qt.inputMethod.commit();
                    Qt.inputMethod.hide();
                    if (messageField.text !== "") {
                        py.call('backend.send_message', [conv_id, messageField.text]);
                        messageField.text = "";
                        py.call('backend.set_typing', [conv_id, "stopped"]);
                        pausedTypingTimer.stop();
                        stoppedTypingTimer.stop();
                    }
                }

            }

        }

        ColorOverlay {
            anchors.fill: sendIcon
            source: sendIcon
            color: UbuntuColors.blue
        }

    }

    ImportContentPopup {
        id: importContentPopup
        contentType: ContentType.Pictures
        onItemsImported: {
            var picture = importItems[0];
            var url = picture.url;
            py.call('backend.send_image', [conv_id, url.toString()]);
        }
    }

}

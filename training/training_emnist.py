import argparse
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, Dataset
from torchvision import datasets, transforms
from tqdm import tqdm

class EmnistDataset(Dataset):
    def __init__(self, root, train=True):
        # EMNIST 이미지는 일반 MNIST와 방향이 다르게 저장되어 있음
        # x.squeeze(0).T 로 글자방향을 맞춘다.
        transform = transforms.Compose([
            transforms.ToTensor(),
            transforms.Lambda(lambda x: x.squeeze(0).T.reshape(1, 28, 28))
        ])
        self.dataset = datasets.EMNIST(
            root=root,
            split='letters',
            train=train,
            download=True,
            transform=transform,
        )
    def __len__(self):
        return len(self.dataset)
    def __getitem__(self, index):
        image, label = self.dataset[index]
        # EMNIST Letters : A = 1, B = 2 ...Z = 26
        # 학습용 라벨 A = 0 ... Z = 25
        label = label - 1
        return image, label


class MLP(nn.Module):
    def __init__(self):
        super(MLP, self).__init__()

        self.fc1 = nn.Linear(28 * 28, 64)
        self.fc2 = nn.Linear(64, 26)

    def forward(self, x):
        # 입력 shape: [batch, 1, 28, 28]
        # Linear layer에 넣기 위해 [batch, 784]로 펼친다.
        x = x.view(x.size(0), -1)

        # 첫 번째 layer는 RTL NPU에서도 ReLU를 적용할 은닉층이다.
        x = F.relu(self.fc1(x))

        # 마지막 layer는 A~Z 26개 클래스의 score를 출력한다.
        # CrossEntropyLoss가 softmax를 내부에서 처리하므로 여기서는 raw score를 반환한다.
        return self.fc2(x)


def train_one_epoch(model, loader, optimizer, device):
    # train 모드로 전환한다.
    model.train()

    total_loss = 0.0
    correct = 0
    total = 0

    for images, labels in tqdm(loader, desc='train', leave=False):
        images = images.to(device)
        labels = labels.to(device)

        # 이전 batch의 gradient를 지우고 새 batch에 대한 gradient를 계산한다.
        optimizer.zero_grad()
        outputs = model(images)
        loss = F.cross_entropy(outputs, labels)
        loss.backward()
        optimizer.step()

        # loss는 batch 평균값이므로 샘플 수를 곱해서 전체 평균을 계산한다.
        total_loss += loss.item() * images.size(0)
        preds = outputs.argmax(dim=1)
        correct += (preds == labels).sum().item()
        total += labels.size(0)

    return total_loss / total, correct / total


@torch.no_grad()
def evaluate(model, loader, device):
    # 평가에서는 gradient가 필요 없으므로 @torch.no_grad()로 메모리 사용을 줄인다.
    model.eval()

    total_loss = 0.0
    correct = 0
    total = 0

    for images, labels in tqdm(loader, desc='eval', leave=False):
        images = images.to(device)
        labels = labels.to(device)

        outputs = model(images)
        loss = F.cross_entropy(outputs, labels)

        total_loss += loss.item() * images.size(0)
        preds = outputs.argmax(dim=1)
        correct += (preds == labels).sum().item()
        total += labels.size(0)

    return total_loss / total, correct / total


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data-dir', default='./data')
    parser.add_argument('--out', default='./model.pth')
    parser.add_argument('--epochs', type=int, default=20)
    parser.add_argument('--batch-size', type=int, default=128)
    parser.add_argument('--lr', type=float, default=1e-3)
    args = parser.parse_args()

    # GPU가 있으면 cuda를 쓰고, 없으면 CPU로 학습한다.
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f'device: {device}')

    train_set = EmnistDataset(args.data_dir, train=True)
    test_set = EmnistDataset(args.data_dir, train=False)

    train_loader = DataLoader(
        train_set,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=2,
        pin_memory=(device == 'cuda'),
    )
    test_loader = DataLoader(
        test_set,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=2,
        pin_memory=(device == 'cuda'),
    )

    model = MLP().to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)

    best_acc = 0.0
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    for epoch in range(1, args.epochs + 1):
        train_loss, train_acc = train_one_epoch(model, train_loader, optimizer, device)
        test_loss, test_acc = evaluate(model, test_loader, device)

        print(
            f'epoch {epoch:02d} | '
            f'train loss {train_loss:.4f} acc {train_acc * 100:.2f}% | '
            f'test loss {test_loss:.4f} acc {test_acc * 100:.2f}%'
        )

        # 가장 좋은 test accuracy를 낸 모델만 저장한다.
        if test_acc > best_acc:
            best_acc = test_acc
            torch.save(
                {
                    'model_state': model.state_dict(),
                    'test_acc': test_acc,
                    'epoch': epoch,
                },
                out_path,
            )

    print(f'best test acc: {best_acc * 100:.2f}%')
    print(f'saved: {out_path}')


if __name__ == '__main__':
    main()